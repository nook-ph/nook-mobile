import 'dart:io';

import 'package:nook/core/upload/domain/entities/uploaded_file.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads one gallery photo's file for [cafeId] and returns where it landed.
typedef GalleryFileUploader =
    Future<UploadedFile> Function({required File file, required String cafeId});

/// [IGalleryRepository] on Supabase: the `user_photos` table, with files
/// going through the existing presign upload (`uploadType: gallery_photo`).
/// Row access is enforced by RLS (migration
/// `20261005090000_user_photos_coffee_gallery.sql`).
class GalleryRepositoryImpl implements IGalleryRepository {
  GalleryRepositoryImpl({
    required SupabaseClient client,
    required GalleryFileUploader upload,
  }) : _client = client,
       _upload = upload;

  final SupabaseClient _client;
  final GalleryFileUploader _upload;

  static const _columns =
      'id, user_id, cafe_id, image_url, drink_name, caption, taken_at, source, '
      'source_id, is_hidden, pin_order, cafes(name, neighborhood, city)';

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const GalleryException('Not signed in.');
    return id;
  }

  @override
  Future<List<GalleryPhoto>> getMyPhotos() async {
    try {
      final rows = await _client
          .from('user_photos')
          .select(_columns)
          .eq('user_id', _userId)
          .order('taken_at', ascending: false)
          .limit(500);
      return [for (final row in rows) galleryPhotoFromRow(row)];
    } on PostgrestException catch (e) {
      throw GalleryException('Could not load the gallery.', cause: e);
    }
  }

  @override
  Future<List<GalleryPhoto>> addPhotos({
    required String cafeId,
    required List<PickedGalleryPhoto> photos,
    required GalleryPhotoSource source,
    String? drinkName,
    String? caption,
  }) async {
    if (photos.isEmpty) return const [];
    final userId = _userId;
    final drink = _cleanDrink(drinkName);
    final note = _cleanCaption(caption);
    // Side by side, as review photos are; a batch waits for its slowest.
    final uploaded = await Future.wait([
      for (final photo in photos) _upload(file: photo.file, cafeId: cafeId),
    ]);
    final now = DateTime.now().toUtc();
    try {
      final rows = await _client
          .from('user_photos')
          .insert([
            for (var i = 0; i < photos.length; i++)
              {
                'user_id': userId,
                'cafe_id': cafeId,
                'image_url': uploaded[i].publicUrl,
                'object_key': uploaded[i].objectKey,
                'drink_name': drink,
                'caption': ?note,
                'taken_at': (photos[i].takenAt?.toUtc() ?? now)
                    .toIso8601String(),
                'source': source.wire,
              },
          ])
          .select(_columns);
      return [for (final row in rows) galleryPhotoFromRow(row)];
    } on PostgrestException catch (e) {
      throw GalleryException('Could not save the photos.', cause: e);
    }
  }

  @override
  Future<void> setPinOrder(String photoId, int? pinOrder) =>
      _update(photoId, {'pin_order': pinOrder});

  @override
  Future<void> setHidden(String photoId, {required bool hidden}) =>
      // A hidden photo cannot stay pinned: the pin is for the public.
      _update(photoId, {'is_hidden': hidden, if (hidden) 'pin_order': null});

  @override
  Future<void> setDetails(
    String photoId, {
    String? drinkName,
    String? caption,
  }) => _update(photoId, {
    'drink_name': _cleanDrink(drinkName),
    'caption': _cleanCaption(caption),
  });

  @override
  Future<void> deletePhoto(String photoId) async {
    try {
      await _client.from('user_photos').delete().eq('id', photoId);
    } on PostgrestException catch (e) {
      throw GalleryException('Could not delete the photo.', cause: e);
    }
  }

  Future<void> _update(String photoId, Map<String, dynamic> values) async {
    try {
      await _client.from('user_photos').update(values).eq('id', photoId);
    } on PostgrestException catch (e) {
      throw GalleryException('Could not update the photo.', cause: e);
    }
  }

  static String? _cleanDrink(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.length > 60 ? trimmed.substring(0, 60) : trimmed;
  }

  static String? _cleanCaption(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return trimmed.length > maxGalleryCaption
        ? trimmed.substring(0, maxGalleryCaption)
        : trimmed;
  }
}

/// Maps one `user_photos` row (with its `cafes` join) to a [GalleryPhoto].
GalleryPhoto galleryPhotoFromRow(Map<String, dynamic> row) {
  final cafe = row['cafes'] is Map<String, dynamic>
      ? row['cafes'] as Map<String, dynamic>
      : const <String, dynamic>{};
  final area = [cafe['neighborhood'], cafe['city']]
      .whereType<String>()
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join(', ');
  return GalleryPhoto(
    id: row['id'] as String,
    userId: row['user_id'] as String,
    cafeId: row['cafe_id'] as String,
    cafeName: (cafe['name'] as String?)?.trim().isNotEmpty == true
        ? (cafe['name'] as String).trim()
        : 'Cafe',
    cafeArea: area.isEmpty ? null : area,
    imageUrl: row['image_url'] as String,
    drinkName: row['drink_name'] as String?,
    caption: row['caption'] as String?,
    takenAt:
        DateTime.tryParse(row['taken_at']?.toString() ?? '')?.toLocal() ??
        DateTime.now(),
    source: GalleryPhotoSource.fromWire(row['source'] as String?),
    sourceId: row['source_id'] as String?,
    isHidden: row['is_hidden'] == true,
    pinOrder: (row['pin_order'] as num?)?.toInt(),
  );
}
