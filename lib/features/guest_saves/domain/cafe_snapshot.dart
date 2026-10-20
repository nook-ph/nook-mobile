import 'package:equatable/equatable.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

/// The few fields of a cafe needed to draw its card with no network: kept on
/// the phone beside a guest's save or a recently viewed cafe.
class CafeSnapshot extends Equatable {
  const CafeSnapshot({
    required this.id,
    required this.name,
    this.address = '',
    this.neighborhood,
    this.city,
    this.coverImage,
    this.rating = 0,
    this.reviewCount = 0,
    this.tags = const [],
    this.lat,
    this.lng,
    this.operatingHours,
  });

  final String id;
  final String name;
  final String address;
  final String? neighborhood;
  final String? city;
  final String? coverImage;
  final double rating;
  final int reviewCount;

  /// The featured tags, first one shown on a card. At most three are kept.
  final List<String> tags;
  final double? lat;
  final double? lng;

  /// Raw `cafes.operating_hours`, so the card can say open or closed now.
  final Map<String, dynamic>? operatingHours;

  factory CafeSnapshot.fromDetails(CafeDetailsEntity details) {
    final featured = details.featuredImageUrl?.trim() ?? '';
    final featuredTags = details.tags
        .where((t) => t.isFeatured && t.name.trim().isNotEmpty)
        .map((t) => t.name.trim());
    return CafeSnapshot(
      id: details.id,
      name: details.name,
      address: details.address,
      neighborhood: _blankToNull(details.neighborhood),
      city: _blankToNull(details.city),
      coverImage: featured.isNotEmpty
          ? featured
          : (details.photos.isNotEmpty ? details.photos.first : null),
      rating: details.rating,
      reviewCount: details.reviewCount,
      tags: featuredTags.take(3).toList(),
      lat: details.lat,
      lng: details.lng,
      operatingHours: details.operatingHours.isEmpty
          ? null
          : details.operatingHours,
    );
  }

  factory CafeSnapshot.fromSummary(CafeSummary cafe) => CafeSnapshot(
    id: cafe.id,
    name: cafe.name,
    address: cafe.address,
    neighborhood: cafe.neighborhood,
    city: cafe.city,
    coverImage: cafe.coverImage,
    rating: cafe.rating,
    reviewCount: cafe.reviewCount,
    tags: cafe.tags.take(3).toList(),
    lat: cafe.lat,
    lng: cafe.lng,
    operatingHours: cafe.operatingHours,
  );

  CafeSummary toSummary() => CafeSummary(
    id: id,
    name: name,
    address: address,
    neighborhood: neighborhood,
    city: city,
    coverImage: coverImage,
    rating: rating,
    reviewCount: reviewCount,
    tags: tags,
    lat: lat,
    lng: lng,
    operatingHours: operatingHours,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'neighborhood': ?neighborhood,
    'city': ?city,
    'cover_image': ?coverImage,
    'rating': rating,
    'review_count': reviewCount,
    'tags': tags,
    'lat': ?lat,
    'lng': ?lng,
    'operating_hours': ?operatingHours,
  };

  /// Null when [json] has no usable id or name (a corrupt or foreign entry).
  static CafeSnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String) return null;
    final hours = json['operating_hours'];
    final tags = json['tags'];
    return CafeSnapshot(
      id: id,
      name: name,
      address: json['address'] is String ? json['address'] as String : '',
      neighborhood: _str(json['neighborhood']),
      city: _str(json['city']),
      coverImage: _str(json['cover_image']),
      rating: _num(json['rating'])?.toDouble() ?? 0,
      reviewCount: _num(json['review_count'])?.toInt() ?? 0,
      tags: tags is List ? tags.whereType<String>().toList() : const [],
      lat: _num(json['lat'])?.toDouble(),
      lng: _num(json['lng'])?.toDouble(),
      operatingHours: hours is Map ? Map<String, dynamic>.from(hours) : null,
    );
  }

  static String? _blankToNull(String s) => s.trim().isEmpty ? null : s;

  // Lenient reads: a field of an unexpected type (written by an older or
  // newer build) is dropped, not thrown, so one odd field never costs the
  // whole entry.
  static String? _str(Object? v) => v is String ? v : null;
  static num? _num(Object? v) => v is num ? v : null;

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    neighborhood,
    city,
    coverImage,
    rating,
    reviewCount,
    tags,
    lat,
    lng,
    operatingHours,
  ];
}

/// A Want to Try or Been a guest made, kept on this phone until they sign in.
class GuestSave extends Equatable {
  const GuestSave({
    required this.cafe,
    required this.status,
    required this.savedAt,
    this.owner,
  });

  final CafeSnapshot cafe;

  /// [CafeStatus.wantToTry] or [CafeStatus.been]; never none.
  final CafeStatus status;
  final DateTime savedAt;

  /// The account (user id) a merge was tried for and could not move this
  /// save to. Null for a save made while signed out that no merge has
  /// tried yet: that one moves to whoever signs in. One with an owner moves
  /// on its own only into that account; any other account is asked first.
  final String? owner;

  String get cafeId => cafe.id;

  GuestSave withOwner(String? owner) =>
      GuestSave(cafe: cafe, status: status, savedAt: savedAt, owner: owner);

  Map<String, dynamic> toJson() => {
    'cafe': cafe.toJson(),
    'status': status.wire,
    'saved_at': savedAt.toUtc().toIso8601String(),
    'owner': ?owner,
  };

  static GuestSave? fromJson(Object? json) {
    if (json is! Map) return null;
    final cafe = CafeSnapshot.fromJson(json['cafe']);
    final status = CafeStatus.fromWire(CafeSnapshot._str(json['status']));
    final savedAt = DateTime.tryParse(
      CafeSnapshot._str(json['saved_at']) ?? '',
    );
    if (cafe == null || status == CafeStatus.none || savedAt == null) {
      return null;
    }
    final owner = CafeSnapshot._str(json['owner']);
    return GuestSave(
      cafe: cafe,
      status: status,
      savedAt: savedAt,
      owner: owner == null || owner.isEmpty ? null : owner,
    );
  }

  @override
  List<Object?> get props => [cafe, status, savedAt, owner];
}

/// A cafe whose page was opened on this phone.
class RecentlyViewedCafe extends Equatable {
  const RecentlyViewedCafe({required this.cafe, required this.viewedAt});

  final CafeSnapshot cafe;
  final DateTime viewedAt;

  Map<String, dynamic> toJson() => {
    'cafe': cafe.toJson(),
    'viewed_at': viewedAt.toUtc().toIso8601String(),
  };

  static RecentlyViewedCafe? fromJson(Object? json) {
    if (json is! Map) return null;
    final cafe = CafeSnapshot.fromJson(json['cafe']);
    final at = DateTime.tryParse(CafeSnapshot._str(json['viewed_at']) ?? '');
    if (cafe == null || at == null) return null;
    return RecentlyViewedCafe(cafe: cafe, viewedAt: at);
  }

  @override
  List<Object?> get props => [cafe, viewedAt];
}
