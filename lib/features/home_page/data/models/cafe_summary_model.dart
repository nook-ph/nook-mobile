import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';

class CafeSummaryModel extends CafeSummaryEntity {
  final bool isNew;
  final double? distanceMeters;

  CafeSummaryModel({
    required super.id,
    required super.name,
    required super.address,
    required super.rating,
    super.featuredImageUrl,
    super.isFeatured = false,
    super.tags = const [],
    this.isNew = false,
    this.distanceMeters,
  });

  factory CafeSummaryModel.fromJson(Map<String, dynamic> json) {
    final parsedTags = _parseTags(json);

    return CafeSummaryModel(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      address: '${json['address'] ?? ''}',
      rating: _asDouble(json['rating']) ?? 0,
      featuredImageUrl: _asNullableString(json['featured_image_url']),
      tags: parsedTags,
      isFeatured: _asBool(json['is_featured']) ?? false,
      isNew: _asBool(json['is_new']) ?? false,
      distanceMeters: _asDouble(json['distance_meters']),
    );
  }

  static List<String> _parseTags(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    if (rawTags is List) {
      return rawTags
          .map<String?>((item) {
            if (item is String) return item.trim().isEmpty ? null : item.trim();
            if (item is Map) {
              final name = item['name'];
              if (name is String && name.trim().isNotEmpty) {
                return name.trim();
              }
            }
            return null;
          })
          .whereType<String>()
          .toList();
    }

    final legacyCafeTags = json['cafe_tags'];
    if (legacyCafeTags is List) {
      return legacyCafeTags
          .map<String?>((item) {
            if (item is! Map) return null;
            final nestedTag = item['tags'];
            if (nestedTag is Map) {
              final name = nestedTag['name'];
              if (name is String && name.trim().isNotEmpty) {
                return name.trim();
              }
            }
            return null;
          })
          .whereType<String>()
          .toList();
    }

    return const [];
  }

  static String? _asNullableString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static bool? _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
