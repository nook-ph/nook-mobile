import 'package:nook/features/crawl/data/models/crawl_model.dart';
import 'package:nook/features/crawl/data/models/crawl_progress_model.dart';
import 'package:nook/features/crawl/data/models/crawl_stop_model.dart';
import 'package:nook/features/crawl/data/models/crawl_tier_model.dart';
import 'package:nook/features/crawl/domain/entities/crawl_detail.dart';

class CrawlDetailModel extends CrawlDetail {
  const CrawlDetailModel({
    required super.crawl,
    super.isRegistered = false,
    super.userProgress,
    super.stops = const [],
    super.tiers = const [],
  });

  factory CrawlDetailModel.fromJson(Map<String, dynamic> json) {
    final crawlJson = json['crawl'] is Map
        ? Map<String, dynamic>.from(json['crawl'] as Map)
        : json;

    final stopsList = (json['stops'] as List?)
            ?.whereType<Map>()
            .map((m) => CrawlStopModel.fromJson(Map<String, dynamic>.from(m)))
            .toList() ??
        const [];

    final tiersList = (json['tiers'] as List?)
            ?.whereType<Map>()
            .map((m) => CrawlTierModel.fromJson(Map<String, dynamic>.from(m)))
            .toList() ??
        const [];

    final progressJson = json['progress'];
    final progress = progressJson is Map
        ? CrawlProgressModel.fromJson(Map<String, dynamic>.from(progressJson))
        : null;

    return CrawlDetailModel(
      crawl: CrawlModel.fromJson(crawlJson),
      isRegistered: _asBool(json['is_registered']),
      userProgress: progress,
      stops: stopsList,
      tiers: tiersList,
    );
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.trim().toLowerCase();
      return s == 'true' || s == '1';
    }
    return false;
  }
}
