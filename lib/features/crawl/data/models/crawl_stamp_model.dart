import 'package:nook/features/crawl/domain/entities/crawl_stamp.dart';

class CrawlStampModel extends CrawlStamp {
  const CrawlStampModel({
    required super.id,
    required super.stopId,
    required super.cafeId,
    required super.cafeName,
    super.stopOrder = 0,
    required super.tier,
    required super.claimedAt,
    required super.claimMethod,
    super.isVerified = false,
  });

  factory CrawlStampModel.fromJson(Map<String, dynamic> json) {
    return CrawlStampModel(
      id: _asString(json['id']),
      stopId: _asString(json['stop_id']),
      cafeId: _asString(json['cafe_id']),
      cafeName: _asString(json['cafe_name']),
      stopOrder: _asInt(json['stop_order']),
      tier: _asString(json['tier']),
      claimedAt: _asDateTime(json['claimed_at']),
      claimMethod: _asString(json['claim_method']),
      isVerified: _asBool(json['is_verified']),
    );
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
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

  static DateTime _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
