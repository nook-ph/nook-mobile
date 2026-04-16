class CafeSummary {
  final String id;
  final String name;
  final String address;
  final String? coverImage;
  final double rating;
  final List<String> tags;
  final double? lat;
  final double? lng;
  final double? distanceMeters;
  final bool isFeatured;
  final bool isNew;

  const CafeSummary({
    required this.id,
    required this.name,
    this.address = '',
    this.coverImage,
    required this.rating,
    this.tags = const [],
    this.lat,
    this.lng,
    this.distanceMeters,
    this.isFeatured = false,
    this.isNew = false,
  });
}
