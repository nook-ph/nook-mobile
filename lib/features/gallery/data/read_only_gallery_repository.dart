import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';

/// A gallery that only reads: photos already loaded elsewhere (someone's
/// profile, a cafe's community photos). Lets the shared viewer, which reads
/// a [GalleryCubit], run on photos that are not the viewer's own.
class ReadOnlyGalleryRepository implements IGalleryRepository {
  const ReadOnlyGalleryRepository(this.photos);

  final List<GalleryPhoto> photos;

  @override
  Future<List<GalleryPhoto>> getMyPhotos() async => photos;

  @override
  Future<List<GalleryPhoto>> addPhotos({
    required String cafeId,
    required List<PickedGalleryPhoto> photos,
    required GalleryPhotoSource source,
    String? drinkName,
    String? caption,
  }) => throw UnsupportedError('Read only');

  @override
  Future<void> deletePhoto(String photoId) =>
      throw UnsupportedError('Read only');

  @override
  Future<void> setDetails(
    String photoId, {
    String? drinkName,
    String? caption,
    String? cafeId,
  }) => throw UnsupportedError('Read only');

  @override
  Future<void> setHidden(String photoId, {required bool hidden}) =>
      throw UnsupportedError('Read only');

  @override
  Future<void> setPinOrder(String photoId, int? pinOrder) =>
      throw UnsupportedError('Read only');
}
