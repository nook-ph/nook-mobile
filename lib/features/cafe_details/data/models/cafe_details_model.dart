import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

class CafeDetailsModel extends CafeDetailsEntity {
  CafeDetailsModel({
    required super.id,
    required super.createdAt,
    required super.name,
    required super.description,
    required super.address,
    required super.neighborhood,
    required super.lat,
    required super.lng,
    super.featuredImageUrl,
    required super.rating,
    required super.reviewCount,
    required super.isNew,
    super.operatingHours = const {},
    super.socialLinks = const {},
    super.menuItems = const [],
    super.tags = const [],
    super.reviews = const [],
  });

  factory CafeDetailsModel.fromJson(Map<String, dynamic> json) {
    final menuItems = _parseList(
      json['menu_items'],
    ).map((item) => MenuItemModel.fromJson(item)).toList();

    final tags = _parseTags(json);

    final reviews = _parseList(
      json['reviews'],
    ).map((item) => ReviewModel.fromJson(item)).toList();

    return CafeDetailsModel(
      id: _asString(json['id']),
      createdAt: _asDateTime(json['created_at']),
      name: _asString(json['name']),
      description: _asString(json['description']),
      address: _asString(json['address']),
      neighborhood: _asString(json['neighborhood']),
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      featuredImageUrl: _asNullableString(
        json['featured_image_url'] ?? json['featuredImageUrl'],
      ),
      rating: _asDouble(json['rating']),
      reviewCount: _asInt(json['review_count'] ?? json['reviewCount']),
      isNew: _asBool(json['is_new'] ?? json['isNew']),
      operatingHours: _asMap(json['operating_hours'] ?? json['operatingHours']),
      socialLinks: _asMap(json['social_links'] ?? json['socialLinks']),
      menuItems: menuItems,
      tags: tags,
      reviews: reviews,
    );
  }

  static List<TagModel> _parseTags(Map<String, dynamic> json) {
    if (json['cafe_tags'] is List) {
      return _parseList(json['cafe_tags']).map((item) {
        final merged = <String, dynamic>{
          ...(item['tags'] is Map<String, dynamic>
              ? item['tags'] as Map<String, dynamic>
              : <String, dynamic>{}),
          ...(item['tag'] is Map<String, dynamic>
              ? item['tag'] as Map<String, dynamic>
              : <String, dynamic>{}),
          'is_featured': item['is_featured'] ?? item['isFeatured'],
        };
        return TagModel.fromJson(merged);
      }).toList();
    }

    return _parseList(
      json['tags'],
    ).map((item) => TagModel.fromJson(item)).toList();
  }

  static List<Map<String, dynamic>> _parseList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static String? _asNullableString(dynamic value) {
    final parsed = value?.toString();
    if (parsed == null || parsed.isEmpty) return null;
    return parsed;
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String)
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry('$key', value));
    }
    return const {};
  }
}

class MenuItemModel extends MenuItemEntity {
  MenuItemModel({
    required super.id,
    required super.cafeId,
    required super.name,
    required super.price,
    super.imageUrl,
    required super.isHighlight,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: CafeDetailsModel._asString(json['id']),
      cafeId: CafeDetailsModel._asString(json['cafe_id'] ?? json['cafeId']),
      name: CafeDetailsModel._asString(json['name']),
      price: CafeDetailsModel._asDouble(json['price']),
      imageUrl: CafeDetailsModel._asNullableString(
        json['image_url'] ?? json['imageUrl'],
      ),
      isHighlight: CafeDetailsModel._asBool(
        json['is_highlight'] ?? json['isHighlight'],
      ),
    );
  }
}

class TagModel extends TagEntity {
  TagModel({
    required super.id,
    required super.name,
    super.category,
    super.iconName,
    super.createdAt,
    super.isFeatured = false,
  });

  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(
      id: CafeDetailsModel._asString(json['id']),
      name: CafeDetailsModel._asString(json['name']),
      category: CafeDetailsModel._asNullableString(json['category']),
      iconName: CafeDetailsModel._asNullableString(
        json['icon_name'] ?? json['iconName'],
      ),
      createdAt: json['created_at'] != null
          ? CafeDetailsModel._asDateTime(json['created_at'])
          : null,
      isFeatured: CafeDetailsModel._asBool(
        json['is_featured'] ?? json['isFeatured'],
      ),
    );
  }
}

class ReviewModel extends ReviewEntity {
  ReviewModel({
    required super.id,
    required super.cafeId,
    required super.userId,
    required super.rating,
    required super.content,
    required super.createdAt,
    required super.updatedAt,
    super.name,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: CafeDetailsModel._asString(json['id']),
      cafeId: CafeDetailsModel._asString(json['cafe_id'] ?? json['cafeId']),
      userId: CafeDetailsModel._asString(json['user_id'] ?? json['userId']),
      rating: CafeDetailsModel._asInt(json['rating']),
      content: CafeDetailsModel._asString(json['content']),
      createdAt: CafeDetailsModel._asDateTime(
        json['created_at'] ?? json['createdAt'],
      ),
      updatedAt: CafeDetailsModel._asDateTime(
        json['updated_at'] ?? json['updatedAt'],
      ),
      name: CafeDetailsModel._asNullableString(
        json['name'] ??
            json['profiles']?['name'] ??
            json['users']?['name'] ??
            json['user']?['name'] ??
            json['profiles']?['full_name'] ??
            json['users']?['full_name'] ??
            json['user']?['full_name'],
      ),
    );
  }
}
