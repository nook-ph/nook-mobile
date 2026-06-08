class CrawlDeepLinkResult {
  final String crawlId;
  final String stopId;

  const CrawlDeepLinkResult({required this.crawlId, required this.stopId});
}

class CrawlDeepLinkHandler {
  static const scheme = 'nook';
  static const host = 'crawl';

  static bool canHandle(Uri uri) =>
      uri.scheme == scheme && uri.host == host;

  static CrawlDeepLinkResult? parse(Uri uri) {
    if (!canHandle(uri)) return null;

    final segments = uri.pathSegments;
    if (segments.length == 4 &&
        segments[1] == 'stop' &&
        segments[3] == 'claim') {
      return CrawlDeepLinkResult(
        crawlId: segments[0],
        stopId: segments[2],
      );
    }

    return null;
  }
}
