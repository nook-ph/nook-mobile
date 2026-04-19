class CafeDetails {
  final String id;
  final DateTime createdAt;
  final String name;
  final String description;
  final String address;
  final String neighborhood;
  final String city;
  final double lat;
  final double lng;
  final String? coverImage;
  final List<String> photos;
  final double rating;
  final int reviewCount;
  final bool isNew;
  final Map<String, dynamic> operatingHours;
  final Map<String, dynamic> socialLinks;
  final List<Tag> tags;

  const CafeDetails({
    required this.id,
    required this.createdAt,
    required this.name,
    required this.description,
    required this.address,
    required this.neighborhood,
    this.city = '',
    required this.lat,
    required this.lng,
    this.coverImage,
    this.photos = const [],
    required this.rating,
    required this.reviewCount,
    required this.isNew,
    this.operatingHours = const {},
    this.socialLinks = const {},
    this.tags = const [],
  });
}

class MenuItem {
  final String id;
  final String cafeId;
  final String name;
  final double price;
  final String? imageUrl;
  final bool isHighlight;
  final String? categoryId;
  final String? categoryName;

  const MenuItem({
    required this.id,
    required this.cafeId,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.isHighlight,
    this.categoryId,
    this.categoryName,
  });
}

class Tag {
  final String id;
  final String name;
  final String? category;
  final String? iconName;
  final DateTime? createdAt;
  final bool isFeatured;

  const Tag({
    required this.id,
    required this.name,
    this.category,
    this.iconName,
    this.createdAt,
    this.isFeatured = false,
  });
}

class Review {
  final String id;
  final String cafeId;
  final String userId;
  final int rating;
  final String content;
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? name;
  final int helpfulCount;
  final bool hasVoted;

  const Review({
    required this.id,
    required this.cafeId,
    required this.userId,
    required this.rating,
    required this.content,
    this.imageUrls = const [],
    required this.createdAt,
    required this.updatedAt,
    this.name,
    this.helpfulCount = 0,
    this.hasVoted = false,
  });
}
