class CafeSummary {
  final String id;
  final String name;
  final String address;
  final String? neighborhood;
  final String? city;
  final String? coverImage;
  final List<String> photoUrls;
  final double rating;
  final int reviewCount;
  final List<String> tags;
  final double? lat;
  final double? lng;
  final double? distanceMeters;
  final bool isFeatured;
  final bool isNew;
  final bool isFavorited;

  const CafeSummary({
    required this.id,
    required this.name,
    this.address = '',
    this.neighborhood,
    this.city,
    this.coverImage,
    this.photoUrls = const [],
    required this.rating,
    this.reviewCount = 0,
    this.tags = const [],
    this.lat,
    this.lng,
    this.distanceMeters,
    this.isFeatured = false,
    this.isNew = false,
    this.isFavorited = false,
  });

  String get locationLabel {
    final parts = [neighborhood, city]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim())
        .toList();
    return parts.isNotEmpty ? parts.join(', ') : address;
  }
}
