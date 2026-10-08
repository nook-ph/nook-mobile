import 'package:equatable/equatable.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';

/// A profile as someone other than its owner sees it, from
/// `get_public_profile`. Also what the owner's "View as visitor" shows.
class PublicProfile extends Equatable {
  const PublicProfile({
    required this.userId,
    required this.username,
    required this.reviewCount,
    this.fullName,
    this.avatarUrl,
    this.bio,
    this.highlightsPublic = true,
    this.isSelf = false,
    this.rankedCount,
    this.cupCount,
    this.photos = const [],
    this.reviews = const [],
  });

  final String userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final String? bio;

  /// The owner's "Show my gallery on my profile". Off: no gallery, and no
  /// ranked or cups count.
  final bool highlightsPublic;

  /// The viewer is this person.
  final bool isSelf;

  final int reviewCount;

  /// Null when [highlightsPublic] is off.
  final int? rankedCount;

  /// Visible gallery photos. Null when [highlightsPublic] is off.
  final int? cupCount;

  final List<GalleryPhoto> photos;
  final List<WrittenReview> reviews;

  /// The name to show: the full name, else the handle.
  String get displayName {
    final name = fullName?.trim() ?? '';
    return name.isEmpty ? username : name;
  }

  @override
  List<Object?> get props => [
    userId,
    username,
    fullName,
    avatarUrl,
    bio,
    highlightsPublic,
    isSelf,
    reviewCount,
    rankedCount,
    cupCount,
    photos,
    reviews.map((r) => r.id).toList(),
  ];
}

/// "18 cafes ranked · 4 reviews · 11 cups". Parts the visitor may not see
/// (null) are left out; zero ranked or cups is left out too, since "0 cups"
/// says nothing about a person.
String publicCountsLine({required int reviews, int? ranked, int? cups}) {
  return [
    if (ranked != null && ranked > 0)
      '$ranked ${ranked == 1 ? 'cafe' : 'cafes'} ranked',
    '$reviews ${reviews == 1 ? 'review' : 'reviews'}',
    if (cups != null && cups > 0) '$cups ${cups == 1 ? 'cup' : 'cups'}',
  ].join(' · ');
}

/// Someone found by typing "@" and the start of their username in search.
class PersonMatch extends Equatable {
  const PersonMatch({
    required this.userId,
    required this.username,
    this.fullName,
    this.avatarUrl,
  });

  final String userId;
  final String username;
  final String? fullName;
  final String? avatarUrl;

  @override
  List<Object?> get props => [userId, username, fullName, avatarUrl];
}

/// The username start in a people search ("@bea" → "bea"), or null when
/// [query] is not one: it must be "@" and 1–20 username characters.
String? peopleQuery(String query) {
  final match = RegExp(r'^@([A-Za-z0-9_]{1,20})$').firstMatch(query.trim());
  return match?.group(1);
}

/// A plain query that could be the start of a username ("bea", not "flat
/// white"), so search can offer matching people under the cafes without an
/// "@". Null for anything else, and for an "@" query, which [peopleQuery]
/// covers.
String? looseUsernameQuery(String query) {
  final match = RegExp(r'^([A-Za-z0-9_]{3,20})$').firstMatch(query.trim());
  return match?.group(1);
}
