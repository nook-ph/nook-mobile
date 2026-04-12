class CafeSummary {
  final String id;
  final String name;
  final String address;
  final String? coverImage;
  final double rating;
  final List<String> tags;
  final double? lat;
  final double? lng;
  final double? distance;
  final bool isFeatured;

  const CafeSummary({
    required this.id,
    required this.name,
    this.address = '',
    this.coverImage,
    required this.rating,
    this.tags = const [],
    this.lat,
    this.lng,
    this.distance,
    this.isFeatured = false,
  });
}
