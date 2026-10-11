import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/domain/i_community_photos_repository.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';
import 'package:nook/features/gallery/presentation/stories/story_seen_cubit.dart';

import 'gallery_fakes.dart';

/// A community photo of `cafe-1` by @[username].
CommunityPhoto communityPhoto(
  String id, {
  String username = 'sai',
  bool isSelf = false,
  String? drink,
  DateTime? takenAt,
  GalleryPhotoSource source = GalleryPhotoSource.gallery,
}) => CommunityPhoto(
  photo: galleryPhoto(id, drink: drink, takenAt: takenAt, source: source),
  credit: PhotoCredit(
    userId: 'user-$username',
    username: username,
    isSelf: isSelf,
  ),
);

/// Serves [photos] a page at a time, newest first as given. Records each
/// offset asked for; [failure] makes the next reads throw.
class FakeCommunityPhotosRepository implements ICommunityPhotosRepository {
  FakeCommunityPhotosRepository([List<CommunityPhoto>? photos])
    : photos = [...?photos];

  List<CommunityPhoto> photos;
  Object? failure;
  final List<int> offsets = [];

  @override
  Future<CommunityPhotoPage> getCafePhotos(
    String cafeId, {
    required int limit,
    int offset = 0,
  }) async {
    offsets.add(offset);
    final error = failure;
    if (error != null) throw error;
    final page = photos.skip(offset).take(limit).toList();
    return CommunityPhotoPage(
      photos: page,
      total: photos.length,
      hasMore: offset + page.length < photos.length,
      nextOffset: offset + page.length,
    );
  }
}

const offline = GalleryException('Could not load the photos.');

/// Seen story photos in memory; [saved] is the last set written.
class MemoryStorySeenStore implements StorySeenStore {
  MemoryStorySeenStore([Set<String>? initial]) : saved = {...?initial};

  Set<String> saved;

  @override
  Future<Set<String>> load() async => {...saved};

  @override
  Future<void> save(Set<String> seen) async => saved = {...seen};
}
