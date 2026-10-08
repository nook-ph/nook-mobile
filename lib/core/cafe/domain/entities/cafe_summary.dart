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

  /// Raw `cafes.operating_hours` JSON, used to derive the open/closed badge.
  /// Null when the read path doesn't select it — the badge is then omitted
  /// rather than guessed at (see `CafeOpenStatus`).
  final Map<String, dynamic>? operatingHours;

  /// The caller's private note from the list membership row. Only list read
  /// paths carry it; null elsewhere.
  final String? note;

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
    this.operatingHours,
    this.note,
  });

  /// This cafe with [meters] as its distance; everything else unchanged.
  CafeSummary withDistance(double meters) => CafeSummary(
    id: id,
    name: name,
    address: address,
    neighborhood: neighborhood,
    city: city,
    coverImage: coverImage,
    photoUrls: photoUrls,
    rating: rating,
    reviewCount: reviewCount,
    tags: tags,
    lat: lat,
    lng: lng,
    distanceMeters: meters,
    isFeatured: isFeatured,
    isNew: isNew,
    isFavorited: isFavorited,
    operatingHours: operatingHours,
    note: note,
  );

  String get locationLabel {
    final parts = [neighborhood, city]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim())
        .toList();
    return parts.isNotEmpty ? parts.join(', ') : address;
  }
}
