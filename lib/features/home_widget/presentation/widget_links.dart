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
/// opens it from there with [WidgetLinks.take]. That is the cold-start
/// route; a warm tap comes only from the plugin ([acceptFromPlatform]),
/// since MainActivity sends no route for it (go_router would turn it into
/// a go('/') that replaces the page stack, a page saving behind a PopScope
/// included).
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
  /// [pending]), else null.
  static String? accept(Uri uri) {
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
      _pendingAt = now;
      pending.value = link;
    }
    return '/';
  }

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
    if (uri != null) accept(uri);
  }

  /// The pending link, cleared; null when there is none or it waited too
  /// long (logged as a dropped tap).
  static WidgetLink? take() {
    final link = pending.value;
    final at = _pendingAt;
    pending.value = null;
    _pendingAt = null;
    if (link == null) return null;
    if (at != null && clock().difference(at) > _openWithin) {
      logTap(link, blocked: true);
      return null;
    }
    return link;
  }

  /// `widget_tapped`, once per tap, when the app has acted on it: opened,
  /// or dropped ([blocked]) because a page refusing Back or a sheet was on
  /// top, or the shell did not show in time.
  static void logTap(WidgetLink link, {required bool blocked}) {
    logAppEvent(
      HomeWidgetEvents.tapped,
      properties: {'target': link.tap, 'blocked': blocked},
    );
  }

  /// Mounted [WidgetLinkOpener]s: the tab shell is built.
  static int _openers = 0;
  static bool _shellSeen = false;

  static void openerAttached() {
    _openers++;
    _shellSeen = true;
  }

  static void openerDetached() => _openers--;

  /// A link waits and nothing will open it: the shell this run showed is
  /// gone (signed out to `/login`, say). A warm Android tap sends no route
  /// (MainActivity), so the app goes back to `/` itself for it. Not before
  /// the shell first shows: a cold start gets there on its own, through
  /// onboarding or account setup.
  static bool get needsShell =>
      pending.value != null && _openers == 0 && _shellSeen;

  @visibleForTesting
  static void reset() {
    _openers = 0;
    _shellSeen = false;
    _lastKey = null;
    _lastAt = null;
    _pendingAt = null;
    pending.value = null;
    clock = DateTime.now;
  }
}
