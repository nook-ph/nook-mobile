import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';

/// The coffee gallery's data (`user_photos`). Behind an interface so the
/// screens run against a fake in tests and in the debug demo.
abstract interface class IGalleryRepository {
  /// The signed-in person's photos, hidden ones included, in no particular
  /// order (the cubit sorts).
  Future<List<GalleryPhoto>> getMyPhotos();

  /// Uploads [photos] and adds them to [cafeId]. Returns the new rows.
  /// [drinkName] and [caption] apply to every photo in the batch.
  Future<List<GalleryPhoto>> addPhotos({
    required String cafeId,
    required List<PickedGalleryPhoto> photos,
    required GalleryPhotoSource source,
    String? drinkName,
    String? caption,
  });

  /// Sets or clears (null) a photo's pin slot, 1–3.
  Future<void> setPinOrder(String photoId, int? pinOrder);

  Future<void> setHidden(String photoId, {required bool hidden});

  /// Sets the drink and the note together; null clears either. A
  /// [cafeId] moves the photo to that cafe (never a review photo); null
  /// leaves the cafe as it is.
  Future<void> setDetails(
    String photoId, {
    String? drinkName,
    String? caption,
    String? cafeId,
  });

  /// Not allowed for review photos; the server refuses it too.
  Future<void> deletePhoto(String photoId);
}

/// Thrown by the repository when a gallery read or write fails.
class GalleryException implements Exception {
  const GalleryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'GalleryException: $message';
}
