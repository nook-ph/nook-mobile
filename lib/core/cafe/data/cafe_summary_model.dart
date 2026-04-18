import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

class CafeSummaryModel extends CafeSummary {
  const CafeSummaryModel({
    required super.id,
    required super.name,
    super.address = '',
    super.coverImage,
    required super.rating,
    super.tags = const [],
    super.lat,
    super.lng,
    super.distanceMeters,
    super.isFeatured = false,
    super.isNew = false,
  });

  factory CafeSummaryModel.fromJson(Map<String, dynamic> json) {
    return CafeSummaryModel(
      id: _asString(json['id']),
      name: _asString(json['name']),
      address: _asString(json['address']),
      coverImage: _asNullableString(json['featured_image_url']),
      rating: _asDouble(json['rating']),
      tags: _parseTags(json),
      isFeatured: _asBool(json['is_featured']),
      isNew: _asBool(json['is_new']),
      distanceMeters: _asNullableDouble(json['distance_meters']),
      lat: _asNullableDouble(json['lat']),
      lng: _asNullableDouble(json['lng']),
    );
  }

  /// Returns only tags where [is_featured] is true in the cafe_tags join row.
  static List<String> _parseTags(Map<String, dynamic> json) {
    final cafeTags = json['cafe_tags'];
    if (cafeTags is List) {
      return cafeTags
          .where((item) => item is Map && item['is_featured'] == true)
          .map<String?>((item) {
            final tag = (item as Map)['tags'];
            if (tag is Map) {
              final name = tag['name'];
              if (name is String && name.trim().isNotEmpty) return name.trim();
            }
            return null;
          })
          .whereType<String>()
          .toList();
    }

    // RPC path: filter maps by is_featured when available; plain strings have
    // no featured signal so they are excluded to be safe.
    final tags = json['tags'];
    if (tags is List) {
      return tags
          .where((item) => item is Map && item['is_featured'] == true)
          .map<String?>((item) {
            final name = (item as Map)['name'];
            if (name is String && name.trim().isNotEmpty) return name.trim();
            return null;
          })
          .whereType<String>()
          .toList();
    }

    return const [];
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static String? _asNullableString(dynamic value) {
    final str = value?.toString().trim();
    return (str == null || str.isEmpty) ? null : str;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
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
