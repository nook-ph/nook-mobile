import 'package:nook/features/crawl/data/models/crawl_stamp_model.dart';
import 'package:nook/features/crawl/data/models/crawl_tier_model.dart';
import 'package:nook/features/crawl/domain/entities/crawl_progress.dart';

class CrawlProgressModel extends CrawlProgress {
  const CrawlProgressModel({
    super.totalStamps = 0,
    super.highestTier,
    super.stamps = const [],
  });

  factory CrawlProgressModel.fromJson(Map<String, dynamic> json) {
    final highestTierJson = json['highest_tier'];
    final CrawlTierModel? highestTier = highestTierJson is Map
        ? CrawlTierModel.fromJson(Map<String, dynamic>.from(highestTierJson))
        : null;

    final stampsList = (json['stamps'] as List?)
            ?.whereType<Map>()
            .map((m) => CrawlStampModel.fromJson(Map<String, dynamic>.from(m)))
            .toList() ??
        const [];

    return CrawlProgressModel(
      totalStamps: _asInt(json['total_stamps']),
      highestTier: highestTier,
      stamps: stampsList,
    );
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }
}
