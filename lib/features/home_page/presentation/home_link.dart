import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/home_page/domain/use_cases/get_cafe_summaries_usecase.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hosts whose links the app opens itself (App Links / Universal Links).
const _appLinkHosts = {'www.nookph.app', 'nookph.app'};

/// Paths under those hosts that have an in-app page (see `app_router.dart`).
const _appLinkPrefixes = ['/u/', '/c/'];

/// Where a banner link goes inside the app, as a router location, or null
/// when it opens in the browser.
///
/// `nook://<host>/<path>?<query>` maps to `/<host>/<path>?<query>`, so
/// `nook://cafe/<id>` opens Cafe Details and `nook://search?sort=trending`
/// a sorted search. A location with no page lands on the router's "This
/// link doesn't open anything". `https://www.nookph.app/u/…` and `/c/…`
/// open their in-app pages; every other `https` link goes to the browser.
String? inAppLocation(Uri link) {
  if (link.scheme == 'nook') {
    final path = [
      if (link.host.isNotEmpty) link.host,
      ...link.pathSegments.where((s) => s.isNotEmpty),
    ].map(Uri.encodeComponent).join('/');
    return Uri(
      path: '/$path',
      query: link.hasQuery ? link.query : null,
    ).toString();
  }
  if (link.scheme == 'https' &&
      _appLinkHosts.contains(link.host) &&
      _appLinkPrefixes.any(link.path.startsWith)) {
    return Uri(
      path: link.path,
      query: link.hasQuery ? link.query : null,
    ).toString();
  }
  return null;
}

/// Built-in shelves whose full list is a search, as that search's
/// location: `nook://shelf/nearby` opens what Near you's "See all" opens.
/// Null for every other id (custom shelves, House picks, Your places,
/// Laptop-friendly), which the shelf page handles.
String? builtinShelfSearch(String sectionId) => switch (sectionId) {
  'nearby' ||
  'newest' ||
  'trending' ||
  'top_rated' => '/search?sort=$sectionId',
  'specialty' => Uri(
    path: '/search',
    queryParameters: {'tag': specialtyCoffeeTag, 'sort': 'nearby'},
  ).toString(),
  'local_beans' => Uri(
    path: '/search',
    queryParameters: {'tag': localBeansTag},
  ).toString(),
  _ => null,
};

/// Opens [link]: in the app when [inAppLocation] places it, else in the
/// browser. The future completes when the in-app page is closed (or once
/// the browser is asked).
///
/// [extra] goes to the in-app page only when it is a shelf page (the
/// banner passes a `HomeShelfHeader` so a shelf it opens carries its
/// title): other routes read `extra` as their own type and would throw.
/// A browser that cannot be opened is ignored.
Future<void> openHomeLink(
  BuildContext context,
  Uri link, {
  Object? extra,
}) async {
  final location = inAppLocation(link);
  if (location != null) {
    // Completes when that page is closed.
    await context.push<Object?>(
      location,
      extra: location.startsWith('/shelf/') ? extra : null,
    );
    return;
  }
  if (link.scheme == 'https') {
    try {
      await launchUrl(link, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No app can open it: nothing to show.
    }
  }
}
