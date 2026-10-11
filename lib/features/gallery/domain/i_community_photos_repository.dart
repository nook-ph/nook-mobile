import 'package:nook/features/gallery/domain/entities/community_photo.dart';

/// Gallery photos other people added for a cafe, for its details page.
/// Read only; throws [GalleryException] when the read fails.
abstract interface class ICommunityPhotosRepository {
  /// Up to [limit] of [cafeId]'s photos, newest first, skipping [offset].
  Future<CommunityPhotoPage> getCafePhotos(
    String cafeId, {
    required int limit,
    int offset = 0,
  });
}
