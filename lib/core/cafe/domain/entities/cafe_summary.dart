class CafeSummary {
  final String id;
  final String name;
  final String address;
  final String? coverImage;
  final double rating;
  final List<String> tags;
  final bool isFeatured;

  const CafeSummary({
    required this.id,
    required this.name,
    this.address = '',
    this.coverImage,
    required this.rating,
    this.tags = const [],
    this.isFeatured = false,
  });
}
