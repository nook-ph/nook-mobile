import 'package:flutter/foundation.dart';
import 'package:nook/core/analytics/home_widget_events.dart';
import 'package:nook/core/analytics/log_app_event.dart';

/// Where a tap on the home-screen widget goes.
enum WidgetLinkTarget { cafe, saved, home }

/// A link the widget opened the app with:
///
/// - `nook://cafe/<id>?via=widget`, a cafe's row → its page;
/// - `nook://saved?via=widget`, the header → the Saved tab (with
///   `tap=stale` from the "Open Nook to update" state);
/// - `nook://home?via=widget`, the empty state's "Find a cafe" → Home.
///
/// Android hands the link to Flutter as the route, where go_router would
/// read `nook://cafe/<id>` as the path `/<id>`. So the router's redirect
/// passes these to [WidgetLinks.accept], which keeps the link and sends the
/// route to `/` (Home, which Back from the cafe then lands on); `MainShell`
/// opens it from there with [WidgetLinks.take].
class WidgetLink {
  const WidgetLink._(this.target, this.cafeId, this.tap);

  final WidgetLinkTarget target;
  final String? cafeId;

  /// The `target` property of `widget_tapped`.
  final String tap;

  /// The router location to push for a cafe; null for a tab.
  String? get location => cafeId == null ? null : '/cafe/$cafeId';

  static WidgetLink? parse(Uri uri) {
    if (uri.scheme != 'nook' || uri.queryParameters['via'] != 'widget') {
      return null;
    }
    switch (uri.host) {
      case 'cafe':
        final id = uri.pathSegments.where((s) => s.isNotEmpty).firstOrNull;
        if (id == null) return null;
        return WidgetLink._(WidgetLinkTarget.cafe, id, 'cafe');
      case 'saved':
        return WidgetLink._(
          WidgetLinkTarget.saved,
          null,
          uri.queryParameters['tap'] == 'stale' ? 'stale' : 'header',
        );
      case 'home':
        return const WidgetLink._(WidgetLinkTarget.home, null, 'empty');
    }
    return null;
  }
}

abstract final class WidgetLinks {
  /// The widget link waiting to be opened, if any.
  static final ValueNotifier<WidgetLink?> pending = ValueNotifier(null);

  /// One tap can arrive twice: as the route Android hands Flutter (the
  /// router's redirect) and as the widget plugin's launch or click event.
  /// The same link within this window is the same tap.
  static const _sameTap = Duration(seconds: 3);
  static String? _lastKey;
  static DateTime? _lastAt;

  /// The tap a link stands for. Not the Uri itself: go_router hands the
  /// redirect `nook://saved/?via=widget` (an empty path becomes `/`) while
  /// the plugin sends `nook://saved?via=widget`.
  static String _key(WidgetLink link) =>
      '${link.target.name}/${link.cafeId ?? ''}/${link.tap}';

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  /// For the router's redirect: `/` when [uri] is a widget link (kept in
  /// [pending] and logged), else null.
  static String? accept(Uri uri) => _accept(uri, fromRouter: true);

  static String? _accept(Uri uri, {required bool fromRouter}) {
    final link = WidgetLink.parse(uri);
    if (link == null) return null;
    final now = clock();
    final last = _lastAt;
    final key = _key(link);
    final repeat =
        key == _lastKey && last != null && now.difference(last) < _sameTap;
    _lastKey = key;
    _lastAt = now;
    if (!repeat) {
      logAppEvent(HomeWidgetEvents.tapped, properties: {'target': link.tap});
      _setPending(link, now);
    } else if (fromRouter && _lastTaken && link.location != null) {
      // The plugin's link reached Dart before the route, so the cafe may
      // already be open; this redirect's `/` then replaces the stack and
      // closes it. Open it again over the new Home (not logged: it is the
      // same tap). (MainActivity sends no route for a warm Android tap, so
      // that `/` cannot tear down a page saving behind a PopScope.)
      _setPending(link, now);
    }
    return '/';
  }

  static void _setPending(WidgetLink link, DateTime now) {
    _lastTaken = false;
    _pendingAt = now;
    pending.value = link;
  }

  /// Whether the last link has been opened ([take]n).
  static bool _lastTaken = false;
  static DateTime? _pendingAt;

  /// A link not opened within this long is dropped: the shell was not on
  /// screen (onboarding, account setup), and opening it later would come
  /// out of nowhere.
  static const _openWithin = Duration(minutes: 1);

  /// A link from the widget plugin: the intent that started the app, or a
  /// tap while it runs. go_router starts at its initial `/` on a cold start
  /// and a recreated activity gets the tap as a new intent, so the router
  /// alone misses some taps.
  static void acceptFromPlatform(Uri? uri) {
    if (uri != null) _accept(uri, fromRouter: false);
  }

  /// The pending link, cleared; null when there is none or it waited too
  /// long.
  static WidgetLink? take() {
    final link = pending.value;
    final at = _pendingAt;
    pending.value = null;
    _pendingAt = null;
    if (link == null) return null;
    _lastTaken = true;
    if (at != null && clock().difference(at) > _openWithin) return null;
    return link;
  }

  @visibleForTesting
  static void reset() {
    _lastKey = null;
    _lastAt = null;
    _lastTaken = false;
    _pendingAt = null;
    pending.value = null;
    clock = DateTime.now;
  }
}
