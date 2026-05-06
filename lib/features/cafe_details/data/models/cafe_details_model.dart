import 'dart:convert';

import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeDetailsModel extends CafeDetailsEntity {
  CafeDetailsModel({
    required super.id,
    required super.createdAt,
    required super.name,
    required super.description,
    required super.address,
    required super.neighborhood,
    super.city = '',
    required super.lat,
    required super.lng,
    super.featuredImageUrl,
    super.photos = const [],
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
      city: _asString(json['city']),
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      featuredImageUrl: _asNullableString(
        json['featured_image_url'] ?? json['featuredImageUrl'],
      ),
      photos: _asStringList(json['photo_urls'] ?? json['photoUrls']),
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
        final tagPayload = item['tags'] is Map<String, dynamic>
            ? item['tags'] as Map<String, dynamic>
            : item['tag'] is Map<String, dynamic>
            ? item['tag'] as Map<String, dynamic>
            : <String, dynamic>{};

        final featuredFromJoin = item['is_featured'] ?? item['isFeatured'];
        final featuredFromTag =
            tagPayload['is_featured'] ?? tagPayload['isFeatured'];

        final merged = <String, dynamic>{
          ...tagPayload,
          'is_featured': featuredFromJoin ?? featuredFromTag,
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

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
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

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .where((item) => item != null)
          .map((item) => _normalizeStringItem(item.toString()))
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is Map) {
      return value.values
          .where((item) => item != null)
          .map((item) => _normalizeStringItem(item.toString()))
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String && value.isNotEmpty) {
      final trimmed = value.trim();

      if ((trimmed.startsWith('[') && trimmed.endsWith(']')) ||
          (trimmed.startsWith('{') && trimmed.endsWith('}'))) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return _asStringList(decoded);
          }
        } catch (_) {
          // Fallback to Postgres array syntax parsing below.
        }

        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          final inner = trimmed.substring(1, trimmed.length - 1).trim();
          if (inner.isEmpty) return const [];
          return inner
              .split(',')
              .map(_normalizeStringItem)
              .where((item) => item.isNotEmpty)
              .toList();
        }
      }

      final normalized = _normalizeStringItem(trimmed);
      if (normalized.isNotEmpty) {
        return [normalized];
      }
    }

    return const [];
  }

  static String _normalizeStringItem(String value) {
    var result = value.trim();
    if ((result.startsWith('"') && result.endsWith('"')) ||
        (result.startsWith("'") && result.endsWith("'"))) {
      result = result.substring(1, result.length - 1).trim();
    }
    return result;
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

    super.variants = const [],

    super.categoryId,
    super.categoryName,
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

      variants: CafeDetailsModel._parseList(
        json['variants'],
      ).map((item) => MenuItemVariantModel.fromJson(item)).toList(),

      categoryId: CafeDetailsModel._asNullableString(
        json['category_id'] ??
            json['categoryId'] ??
            json['menu_categories']?['id'],
      ),

      categoryName: CafeDetailsModel._asNullableString(
        json['category_name'] ??
            json['categoryName'] ??
            json['menu_categories']?['name'],
      ),
    );
  }
}

class MenuItemVariantModel extends MenuItemVariantEntity {
  const MenuItemVariantModel({
    required super.id,
    required super.label,
    super.priceOverride,
    super.priceModifier = 0,
    super.isDefault = false,
    super.sortOrder = 0,
  });

  factory MenuItemVariantModel.fromJson(Map<String, dynamic> json) {
    return MenuItemVariantModel(
      id: CafeDetailsModel._asString(json['id']),
      label: CafeDetailsModel._asString(json['label']),
      priceOverride: CafeDetailsModel._asNullableDouble(
        json['price_override'] ?? json['priceOverride'],
      ),
      priceModifier: CafeDetailsModel._asDouble(
        json['price_modifier'] ?? json['priceModifier'],
      ),
      isDefault: CafeDetailsModel._asBool(
        json['is_default'] ?? json['isDefault'],
      ),
      sortOrder: CafeDetailsModel._asInt(
        json['sort_order'] ?? json['sortOrder'],
      ),
    );
  }
}

class TagModel extends TagEntity {
  TagModel({
    required super.id,
    required super.name,
    super.category,
    super.createdAt,
    super.isFeatured = false,
  });

  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(
      id: CafeDetailsModel._asString(json['id']),
      name: CafeDetailsModel._asString(json['name']),
      category: CafeDetailsModel._asNullableString(json['category']),
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
    super.imageUrls = const [],
    required super.createdAt,
    required super.updatedAt,
    super.name,
    super.helpfulCount = 0,
    super.hasVoted = false,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final profile = _extractRelationObject(json['profile']);
    final profiles = _extractRelationObject(json['profiles']);
    final users = _extractRelationObject(json['users']);
    final user = _extractRelationObject(json['user']);
    final parsedUserId = CafeDetailsModel._asString(
      json['user_id'] ?? json['userId'],
    );
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentUserDisplayName =
        currentUser != null && currentUser.id == parsedUserId
        ? CafeDetailsModel._asNullableString(
            currentUser.userMetadata?['full_name'] ??
                currentUser.userMetadata?['name'] ??
                currentUser.userMetadata?['user_name'] ??
                currentUser.email,
          )
        : null;
    final resolvedName = CafeDetailsModel._asNullableString(
      profile?['full_name'] ??
          profiles?['full_name'] ??
          users?['full_name'] ??
          user?['full_name'] ??
          // Flat columns returned by the RPC
          json['full_name'] ??
          profile?['username'] ??
          profiles?['username'] ??
          users?['username'] ??
          user?['username'] ??
          // Flat username column from the RPC
          json['username'] ??
          profile?['name'] ??
          profiles?['name'] ??
          users?['name'] ??
          user?['name'] ??
          currentUserDisplayName ??
          json['name'],
    );

    return ReviewModel(
      id: CafeDetailsModel._asString(json['id']),
      cafeId: CafeDetailsModel._asString(json['cafe_id'] ?? json['cafeId']),
      userId: parsedUserId,
      rating: CafeDetailsModel._asInt(json['rating']),
      content: CafeDetailsModel._asString(json['content']),
      imageUrls: CafeDetailsModel._asStringList(
        json['image_urls'] ?? json['imageUrls'],
      ),
      createdAt: CafeDetailsModel._asDateTime(
        json['created_at'] ?? json['createdAt'],
      ),
      updatedAt: CafeDetailsModel._asDateTime(
        json['updated_at'] ?? json['updatedAt'],
      ),
      name: resolvedName,
      helpfulCount: CafeDetailsModel._asInt(
        json['helpful_count'] ?? json['helpfulCount'],
      ),
      hasVoted: CafeDetailsModel._asBool(json['has_voted'] ?? json['hasVoted']),
    );
  }

  static Map<String, dynamic>? _extractRelationObject(dynamic relation) {
    if (relation is Map) {
      return Map<String, dynamic>.from(relation);
    }

    if (relation is List) {
      for (final item in relation) {
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
      }
    }

    return null;
  }
}
