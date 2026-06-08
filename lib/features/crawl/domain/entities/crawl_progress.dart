import 'package:nook/features/crawl/domain/entities/crawl_stamp.dart';
import 'package:nook/features/crawl/domain/entities/crawl_tier.dart';

class CrawlProgress {
  final int totalStamps;
  final CrawlTier? highestTier;
  final List<CrawlStamp> stamps;

  const CrawlProgress({
    this.totalStamps = 0,
    this.highestTier,
    this.stamps = const [],
  });
}
