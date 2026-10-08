import 'package:flutter/foundation.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/public_profile/domain/entities/public_profile.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';

/// Whether a debug build fakes public profiles, from
/// `--dart-define=PUBLIC_PROFILE_DEMO=true`. Release builds ignore it.
///
/// `get_public_profile` is not in production yet, so without this every
/// visitor screen shows its error state. The demo reads real cafes (for
/// names and photos) and writes nothing.
bool get publicProfileDemoEnabled =>
    kDebugMode && const bool.fromEnvironment('PUBLIC_PROFILE_DEMO');

/// In-memory [IPublicProfileRepository] for the debug demo.
///
/// Which profile comes back depends on who is asked for, so every state can
/// be reached from the app:
/// - `@nobody`: not found.
/// - `@private`, or a user id that hashes to it: gallery off.
/// - `@onecafe`, or a user id that hashes to it: one ranked cafe.
/// - anyone else: a gallery and reviews.
/// - yourself (the "View as visitor" preview): follows the demo switch.
class DemoPublicProfileRepository implements IPublicProfileRepository {
  DemoPublicProfileRepository({
    required Future<List<CafeSummary>> Function() cafes,
    required String? Function() currentUserId,
    required String Function() currentUserName,
  }) : _cafes = cafes,
       _currentUserId = currentUserId,
       _currentUserName = currentUserName;

  final Future<List<CafeSummary>> Function() _cafes;
  final String? Function() _currentUserId;
  final String Function() _currentUserName;
  bool _myHighlights = true;

  static const _people = [
    (
      'beasantos',
      'Bea Santos',
      'Flat whites and window seats. IT Park on weekdays.',
    ),
    ('onecafe', 'Migs Dela Cruz', null),
    ('private', 'Ana Reyes', 'Matcha first, coffee second.'),
  ];

  @override
  Future<PublicProfile?> getProfile({String? username, String? userId}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (username == 'nobody') return null;
    final self = userId != null && userId == _currentUserId();

    int variant;
    if (username != null) {
      variant = switch (username) {
        'onecafe' => 1,
        'private' => 2,
        _ => 0,
      };
    } else {
      variant = (userId ?? '').codeUnits.fold<int>(0, (a, b) => a + b) % 3;
    }
    if (self) variant = _myHighlights ? 0 : 2;

    final person = _people[variant];
    final handle = self ? 'you' : (username ?? person.$1);
    final name = self ? _currentUserName() : person.$2;
    final public = variant != 2;

    final cafes = await _cafes();
    final now = DateTime.now();
    final photos = <GalleryPhoto>[];
    for (var i = 0; i < cafes.length && photos.length < 9; i++) {
      final cafe = cafes[i];
      for (final url in [cafe.coverImage, ...cafe.photoUrls]) {
        if (url == null || url.isEmpty || photos.length >= 9) continue;
        photos.add(
          GalleryPhoto(
            id: 'demo-${cafe.id}-${photos.length}',
            userId: userId ?? handle,
            cafeId: cafe.id,
            cafeName: cafe.name,
            cafeArea: cafe.neighborhood,
            imageUrl: url,
            drinkName: photos.length.isEven ? 'Iced Spanish latte' : null,
            caption: photos.length % 3 == 0
                ? 'Light roast, tastes like strawberries. Ask for it '
                      'without sugar.'
                : null,
            takenAt: now.subtract(Duration(days: photos.length * 3)),
            source: GalleryPhotoSource.gallery,
            pinOrder: photos.isEmpty ? 1 : null,
          ),
        );
        break;
      }
    }
    final reviews = [
      for (var i = 0; i < cafes.length && i < 3; i++)
        WrittenReview(
          id: 'demo-review-$i',
          cafeId: cafes[i].id,
          cafeName: cafes[i].name,
          rating: 5 - i,
          content: const [
            'Quiet upstairs, strong Wi-Fi and plenty of outlets. Stayed four '
                'hours and nobody minded.',
            'Good pour-over, a little loud after five.',
            '',
          ][i],
          createdAt: now.subtract(Duration(days: 10 * (i + 1))),
          updatedAt: now.subtract(Duration(days: 10 * (i + 1))),
        ),
    ];

    return PublicProfile(
      userId: userId ?? 'demo-$handle',
      username: handle,
      fullName: name,
      bio: person.$3,
      highlightsPublic: public,
      isSelf: self,
      reviewCount: reviews.length,
      rankedCount: public ? (variant == 1 ? 1 : 18) : null,
      cupCount: public ? photos.length : null,
      photos: public ? photos : const [],
      reviews: reviews,
    );
  }

  @override
  Future<List<PersonMatch>> searchPeople(String prefix, {int limit = 5}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final p = prefix.toLowerCase();
    return [
      for (final person in _people)
        if (person.$1.startsWith(p))
          PersonMatch(
            userId: 'demo-${person.$1}',
            username: person.$1,
            fullName: person.$2,
          ),
    ].take(limit).toList();
  }

  @override
  Future<bool> getMyHighlightsPublic() async => _myHighlights;

  @override
  Future<void> setMyHighlightsPublic(bool value) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    _myHighlights = value;
  }

  @override
  Future<void> reportPhoto(String photoId, PhotoReportReason reason) =>
      Future<void>.delayed(const Duration(milliseconds: 400));
}
