import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/features/public_profile/domain/entities/public_profile.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';

import '../gallery/gallery_fakes.dart' show galleryPhoto;

/// In-memory [IPublicProfileRepository]: returns [profile] (null = not
/// found), or throws [failure]; records the switch writes.
class FakePublicProfileRepository implements IPublicProfileRepository {
  FakePublicProfileRepository({this.profile, this.highlights = true});

  PublicProfile? profile;
  bool highlights;
  Object? failure;
  Object? writeFailure;
  final List<({String? username, String? userId})> asked = [];
  final List<bool> writes = [];

  @override
  Future<PublicProfile?> getProfile({String? username, String? userId}) async {
    asked.add((username: username, userId: userId));
    final error = failure;
    if (error != null) throw error;
    return profile;
  }

  List<PersonMatch> people = const [];
  final List<String> searched = [];

  @override
  Future<List<PersonMatch>> searchPeople(String prefix, {int limit = 5}) async {
    searched.add(prefix);
    final error = failure;
    if (error != null) throw error;
    return people;
  }

  @override
  Future<bool> getMyHighlightsPublic() async {
    final error = failure;
    if (error != null) throw error;
    return highlights;
  }

  @override
  Future<void> setMyHighlightsPublic(bool value) async {
    final error = writeFailure;
    if (error != null) throw error;
    writes.add(value);
    highlights = value;
  }
}

PublicTopCafe topCafe(int rank, String name) => PublicTopCafe(
  rank: rank,
  cafeId: 'cafe-$rank',
  name: name,
  area: 'Lahug, Cebu City',
);

WrittenReview publicReview(String id, String cafe) => WrittenReview(
  id: id,
  cafeId: 'cafe-$id',
  cafeName: cafe,
  rating: 4,
  content: 'Quiet upstairs, good Wi-Fi.',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

/// Bea's profile as a visitor gets it, with [top] ranked cafes shown.
PublicProfile beaProfile({
  int top = 3,
  bool highlightsPublic = true,
  bool isSelf = false,
  String? bio = 'Flat whites and window seats.',
}) {
  const names = ['Kamp Craft Coffee', 'Tadaima', 'Pulso'];
  return PublicProfile(
    userId: 'bea-id',
    username: 'beasantos',
    fullName: 'Bea Santos',
    bio: bio,
    highlightsPublic: highlightsPublic,
    isSelf: isSelf,
    reviewCount: 2,
    rankedCount: highlightsPublic ? 18 : null,
    cupCount: highlightsPublic ? 2 : null,
    topCafes: highlightsPublic
        ? [for (var i = 0; i < top; i++) topCafe(i + 1, names[i])]
        : const [],
    photos: highlightsPublic
        ? [galleryPhoto('p1'), galleryPhoto('p2', cafeId: 'cafe-2')]
        : const [],
    reviews: [publicReview('r1', 'Tadaima'), publicReview('r2', 'Pulso')],
  );
}
