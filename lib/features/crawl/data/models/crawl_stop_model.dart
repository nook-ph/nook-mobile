import 'package:nook/features/crawl/domain/entities/crawl_stop.dart';

class CrawlStopModel extends CrawlStop {
  const CrawlStopModel({
    required super.id,
    required super.crawlId,
    required super.cafeId,
    required super.cafeName,
    required super.cafeAddress,
    required super.cafeLat,
    required super.cafeLng,
    required super.stopOrder,
    required super.tier,
    super.isActive = true,
    super.label,
    super.isClaimed = false,
    super.claimedAt,
  });

  factory CrawlStopModel.fromJson(Map<String, dynamic> json) {
    return CrawlStopModel(
      id: _asString(json['id']),
      crawlId: _asString(json['crawl_id']),
      cafeId: _asString(json['cafe_id']),
      cafeName: _asString(json['cafe_name']),
      cafeAddress: _asString(json['cafe_address']),
      cafeLat: _asDouble(json['cafe_lat']),
      cafeLng: _asDouble(json['cafe_lng']),
      stopOrder: _asInt(json['stop_order']),
      tier: _asString(json['tier']),
      isActive: _asBool(json['is_active']),
      label: _asNullableString(json['label']),
      isClaimed: _asBool(json['is_claimed']),
      claimedAt: _asNullableDateTime(json['claimed_at']),
    );
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static String? _asNullableString(dynamic value) {
    final str = value?.toString().trim();
    return (str == null || str.isEmpty) ? null : str;
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
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
