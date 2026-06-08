import 'package:nook/features/crawl/data/models/crawl_tier_model.dart';
import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';

class CrawlShareCardModel extends CrawlShareCardData {
  const CrawlShareCardModel({
    required super.userName,
    required super.crawlTitle,
    required super.crawlPeriod,
    super.totalStamps = 0,
    super.totalStops = 0,
    super.highestTier,
    super.stops = const [],
  });

  factory CrawlShareCardModel.fromJson(Map<String, dynamic> json) {
    final highestTierJson = json['highest_tier'];
    final CrawlTierModel? highestTier = highestTierJson is Map
        ? CrawlTierModel.fromJson(Map<String, dynamic>.from(highestTierJson))
        : null;

    final stopsList = (json['stops'] as List?)
            ?.whereType<Map>()
            .map(
              (m) => CrawlStopShareItemModel.fromJson(
                Map<String, dynamic>.from(m),
              ),
            )
            .toList() ??
        const [];

    return CrawlShareCardModel(
      userName: _asString(json['user_name']),
      crawlTitle: _asString(json['crawl_title']),
      crawlPeriod: _asString(json['crawl_period']),
      totalStamps: _asInt(json['total_stamps']),
      totalStops: _asInt(json['total_stops']),
      highestTier: highestTier,
      stops: stopsList,
    );
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }
}

class CrawlStopShareItemModel extends CrawlStopShareItem {
  const CrawlStopShareItemModel({
    super.stopOrder = 0,
    required super.tier,
    required super.cafeName,
    super.cafeLat = 0,
    super.cafeLng = 0,
    super.isClaimed = false,
    super.claimedAt,
  });

  factory CrawlStopShareItemModel.fromJson(Map<String, dynamic> json) {
    return CrawlStopShareItemModel(
      stopOrder: _asInt(json['stop_order']),
      tier: _asString(json['tier']),
      cafeName: _asString(json['cafe_name']),
      cafeLat: _asDouble(json['cafe_lat']),
      cafeLng: _asDouble(json['cafe_lng']),
      isClaimed: _asBool(json['is_claimed']),
      claimedAt: _asNullableDateTime(json['claimed_at']),
    );
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return 0.0;
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

  static DateTime? _asNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
