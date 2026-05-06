class CafeDetailsEntity {
  final String id;
  final DateTime createdAt;
  final String name;
  final String description;
  final String address;
  final String neighborhood;
  final String city;
  final double lat;
  final double lng;
  final String? featuredImageUrl;
  final List<String> photos;
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
    this.city = '',
    required this.lat,
    required this.lng,
    this.featuredImageUrl,
    this.photos = const [],
    required this.rating,
    required this.reviewCount,
    required this.isNew,
    this.operatingHours = const {},
    this.socialLinks = const {},
    this.menuItems = const [],
    this.tags = const [],
    this.reviews = const [],
  });

  String get locationLabel {
    final parts = [
      neighborhood,
      city,
    ].where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();
    return parts.isNotEmpty ? parts.join(', ') : address;
  }
}

class MenuItemEntity {
  final String id;
  final String cafeId;
  final String name;
  final double price;
  final String? imageUrl;
  final bool isHighlight;

  final List<MenuItemVariantEntity> variants;

  final String? categoryId;
  final String? categoryName;

  MenuItemEntity({
    required this.id,
    required this.cafeId,
    required this.name,
    required this.price,
    this.imageUrl,
    required this.isHighlight,

    this.variants = const [],

    this.categoryId,
    this.categoryName,
  });

  bool get hasVariants => variants.isNotEmpty;

  double get minPrice {
    if (!hasVariants) return price;
    var resolvedMin = variants.first.resolvedPrice(price);
    for (final variant in variants.skip(1)) {
      final resolved = variant.resolvedPrice(price);
      if (resolved < resolvedMin) {
        resolvedMin = resolved;
      }
    }
    return resolvedMin;
  }

  double get maxPrice {
    if (!hasVariants) return price;
    var resolvedMax = variants.first.resolvedPrice(price);
    for (final variant in variants.skip(1)) {
      final resolved = variant.resolvedPrice(price);
      if (resolved > resolvedMax) {
        resolvedMax = resolved;
      }
    }
    return resolvedMax;
  }

  String get displayPrice {
    final min = minPrice;
    final max = maxPrice;
    if (min == max) {
      return min.toStringAsFixed(2);
    }
    return '${min.toStringAsFixed(2)}-${max.toStringAsFixed(2)}';
  }
}

class MenuItemVariantEntity {
  final String id;
  final String label;
  final double? priceOverride;
  final double priceModifier;
  final bool isDefault;
  final int sortOrder;

  const MenuItemVariantEntity({
    required this.id,
    required this.label,
    this.priceOverride,
    this.priceModifier = 0,
    this.isDefault = false,
    this.sortOrder = 0,
  });

  double resolvedPrice(double basePrice) {
    final override = priceOverride;
    if (override != null) return override;
    return basePrice + priceModifier;
  }
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
  final List<String> imageUrls;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? name;
  final int helpfulCount;
  final bool hasVoted;

  ReviewEntity({
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
