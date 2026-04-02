class FavoritesEntity {
  final String userId;
  final String cafeId;
  final DateTime createdAt;

  final String cafeName;
  final String cafeAddress;
  final double cafeRating;
  final String? featuredImageUrl;
  final List<String> tags;

  FavoritesEntity({
    required this.userId,
    required this.cafeId,
    required this.createdAt,
    required this.cafeName,
    required this.cafeAddress,
    required this.cafeRating,
    this.featuredImageUrl,
    this.tags = const [],
  });
}
