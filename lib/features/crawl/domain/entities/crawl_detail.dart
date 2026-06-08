import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/features/crawl/domain/entities/crawl_progress.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stop.dart';
import 'package:nook/features/crawl/domain/entities/crawl_tier.dart';

class CrawlDetail {
  final Crawl crawl;
  final bool isRegistered;
  final CrawlProgress? userProgress;
  final List<CrawlStop> stops;
  final List<CrawlTier> tiers;

  const CrawlDetail({
    required this.crawl,
    this.isRegistered = false,
    this.userProgress,
    this.stops = const [],
    this.tiers = const [],
  });
}
