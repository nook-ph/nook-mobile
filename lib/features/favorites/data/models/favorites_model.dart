import 'package:nook/features/favorites/domain/entities/favorites_entity.dart';

class FavoritesModel extends FavoritesEntity {
  FavoritesModel({
    required super.userId,
    required super.cafeId,
    required super.createdAt,
    required super.cafeName,
    required super.cafeAddress,
    required super.cafeRating,
    super.featuredImageUrl,
    super.tags = const [],
  });

  factory FavoritesModel.fromJson(Map<String, dynamic> json) {
    final cafePayload = json['cafes'] is Map<String, dynamic>
        ? json['cafes'] as Map<String, dynamic>
        : <String, dynamic>{};

    final cafeTags = json['cafe_tags'] is List
        ? (json['cafe_tags'] as List)
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : const <Map<String, dynamic>>[];

    final parsedTags = cafeTags
        .map((item) => item['tags'])
        .whereType<Map>()
        .map((tag) => tag['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    return FavoritesModel(
      userId: json['user_id']?.toString() ?? '',
      cafeId: json['cafe_id']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      cafeName: cafePayload['name']?.toString() ?? '',
      cafeAddress: cafePayload['address']?.toString() ?? '',
      cafeRating: (cafePayload['rating'] as num?)?.toDouble() ?? 0,
      featuredImageUrl: cafePayload['featured_image_url']?.toString(),
      tags: parsedTags,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'cafe_id': cafeId,
      'created_at': createdAt.toIso8601String(),
      'cafes': {
        'name': cafeName,
        'address': cafeAddress,
        'rating': cafeRating,
        'featured_image_url': featuredImageUrl,
      },
    };
  }
}
