import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
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

/// Opens [link]: in the app when [inAppLocation] places it, else in the
/// browser.
Future<void> openHomeLink(BuildContext context, Uri link) async {
  final location = inAppLocation(link);
  if (location != null) {
    context.push(location);
    return;
  }
  if (link.scheme == 'https') {
    await launchUrl(link, mode: LaunchMode.externalApplication);
  }
}
