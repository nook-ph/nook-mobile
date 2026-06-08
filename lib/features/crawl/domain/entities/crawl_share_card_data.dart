import 'package:nook/features/crawl/domain/entities/crawl_tier.dart';

class CrawlShareCardData {
  final String userName;
  final String crawlTitle;
  final String crawlPeriod;
  final int totalStamps;
  final int totalStops;
  final CrawlTier? highestTier;
  final List<CrawlStopShareItem> stops;

  const CrawlShareCardData({
    required this.userName,
    required this.crawlTitle,
    required this.crawlPeriod,
    this.totalStamps = 0,
    this.totalStops = 0,
    this.highestTier,
    this.stops = const [],
  });
}

class CrawlStopShareItem {
  final int stopOrder;
  final String tier;
  final String cafeName;
  final double cafeLat;
  final double cafeLng;
  final bool isClaimed;
  final DateTime? claimedAt;

  const CrawlStopShareItem({
    this.stopOrder = 0,
    required this.tier,
    required this.cafeName,
    this.cafeLat = 0,
    this.cafeLng = 0,
    this.isClaimed = false,
    this.claimedAt,
  });
}
