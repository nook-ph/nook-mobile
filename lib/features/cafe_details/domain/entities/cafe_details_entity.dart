class CafeDetailsEntity {
  final String id;
  final DateTime createdAt;
  final String name;
  final String description;
  final String address;
  final String neighborhood;
  final double lat;
  final double lng;
  final String? featuredImageUrl;
  final double rating;
  final int reviewCount;
  final bool isNew;
  final Map<String, dynamic> operatingHours;
  final Map<String, dynamic> socialLinks;
  final List<MenuItemEntity> menuItems;
  final List<TagEntity> tags;
  final List<ReviewEntity> reviews;

  CafeDetailsEntity({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.description,
    required this.address,
    required this.neighborhood,
    required this.lat,
    required this.lng,
    this.featuredImageUrl,
    required this.rating,
    required this.reviewCount,
    required this.isNew,
    this.operatingHours = const {},
    this.socialLinks = const {},
    this.menuItems = const [],
    this.tags = const [],
    this.reviews = const [],
  });
}

class MenuItemEntity {
  final String id;
  final String cafeId;
  final String name;
  final double price;
  final String? imageUrl;
  final bool isHighlight;

  MenuItemEntity({
    required this.id,
    required this.cafeId,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.isHighlight,
  });
}

class TagEntity {
  final String id;
  final String name;
  final String? category;
  final String? iconName;
  final DateTime? createdAt;
  final bool isFeatured;

  TagEntity({
    required this.id,                                         
    required this.name,
    this.category,
    this.iconName,
    this.createdAt,                                  
    this.isFeatured = false,
  });
}

class ReviewEntity {
  final String id;
  final String cafeId;
  final String userId;
  final int rating;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? name;

  ReviewEntity({
    required this.id,
    required this.cafeId,
    required this.userId,
    required this.rating,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.name,
  });
}
