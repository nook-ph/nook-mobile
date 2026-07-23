import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

class CafeSummaryModel extends CafeSummary {
  const CafeSummaryModel({
    required super.id,
    required super.name,
    super.address = '',
    super.neighborhood,
    super.city,
    super.coverImage,
    super.photoUrls = const [],
    required super.rating,
    super.reviewCount = 0,
    super.tags = const [],
    super.lat,
    super.lng,
    super.distanceMeters,
    super.isFeatured = false,
    super.isNew = false,
    super.isFavorited = false,
    super.operatingHours,
  });

  factory CafeSummaryModel.fromJson(Map<String, dynamic> json) {
    return CafeSummaryModel(
      id: _asString(json['id']),
      name: _asString(json['name']),
      address: _asString(json['address']),
      neighborhood: _asNullableString(json['neighborhood']),
      city: _asNullableString(json['city']),
      coverImage: _asNullableString(json['featured_image_url']),
      photoUrls: _parseStringList(json['photo_urls'] ?? json['photoUrls']),
      rating: _asDouble(json['rating']),
      reviewCount: _asInt(json['review_count'] ?? json['reviewCount']),
      tags: _parseTags(json),
      isFeatured: _asBool(json['is_featured']),
      isNew: _asBool(json['is_new']),
      isFavorited: _asBool(json['is_favorited']),
      distanceMeters: _asNullableDouble(json['distance_meters']),
      lat: _asNullableDouble(json['lat']),
      lng: _asNullableDouble(json['lng']),
      operatingHours: _asNullableMap(json['operating_hours']),
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

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
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

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static Map<String, dynamic>? _asNullableMap(dynamic value) {
    if (value is! Map) return null;
    final map = value.map((key, value) => MapEntry('$key', value));
    return map.isEmpty ? null : map;
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
