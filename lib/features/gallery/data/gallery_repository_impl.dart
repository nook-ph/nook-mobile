import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart' show StringCharacters, debugPrint;
import 'package:nook/core/upload/domain/entities/uploaded_file.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The edge function that deletes a gallery photo's file from Spaces.
const deleteGalleryObjectFunction = 'delete-gallery-object';

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
      'source_id, is_hidden, pin_order, moderation_status, '
      'cafes(name, neighborhood, city)';

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
    final uploaded = await _uploadAll(photos, cafeId);
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
      // "Try again" uploads the files again, so these would be orphans.
      _deleteFiles([for (final file in uploaded) file.objectKey]);
      throw GalleryException('Could not save the photos.', cause: e);
    }
  }

  /// Uploads side by side, as review photos are; a batch waits for its
  /// slowest. If any upload fails, the ones that made it are deleted again
  /// before the error is passed on.
  Future<List<UploadedFile>> _uploadAll(
    List<PickedGalleryPhoto> photos,
    String cafeId,
  ) async {
    final results = await Future.wait([
      for (final photo in photos)
        _upload(file: photo.file, cafeId: cafeId).then<Object>(
          (file) => file,
          onError: (Object e, StackTrace st) => AsyncError(e, st),
        ),
    ]);
    final failure = results.whereType<AsyncError>().firstOrNull;
    final uploaded = results.whereType<UploadedFile>().toList();
    if (failure != null) {
      _deleteFiles([for (final file in uploaded) file.objectKey]);
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    return uploaded;
  }

  /// Asks `delete-gallery-object` to remove files no row points at any more
  /// (nook-supabase `supabase/functions/delete-gallery-object`). Best-effort
  /// and not awaited: the row change already happened, and a file left
  /// behind is only an orphan.
  void _deleteFiles(List<String?> objectKeys) {
    final keys = objectKeys.whereType<String>().toSet().toList();
    if (keys.isEmpty) return;
    unawaited(
      _client.functions
          .invoke(deleteGalleryObjectFunction, body: {'objectKeys': keys})
          .then<void>(
            (_) {},
            onError: (Object e) =>
                debugPrint('[Gallery] files not deleted ($keys): $e'),
          ),
    );
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
    String? cafeId,
  }) => _update(photoId, {
    'drink_name': _cleanDrink(drinkName),
    'caption': _cleanCaption(caption),
    'cafe_id': ?cafeId,
  });

  @override
  Future<void> deletePhoto(String photoId) async {
    try {
      final rows = await _client
          .from('user_photos')
          .delete()
          .eq('id', photoId)
          .select('object_key');
      // Then the file itself, so it stops being public.
      _deleteFiles([for (final row in rows) row['object_key'] as String?]);
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

  static String? _cleanDrink(String? value) => _clip(value, 60);

  static String? _cleanCaption(String? value) =>
      _clip(value, maxGalleryCaption);

  /// Trims [value] and keeps at most [max] characters. The field counts
  /// characters as people see them (grapheme clusters) and the DB checks
  /// code points, so whole characters are kept while both fit: never cut
  /// inside an emoji, and never more than the DB allows. Blank is null.
  static String? _clip(String? value, int max) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.runes.length <= max) return trimmed;
    final kept = StringBuffer();
    var codePoints = 0;
    for (final character in trimmed.characters) {
      codePoints += character.runes.length;
      if (codePoints > max) break;
      kept.write(character);
    }
    final clipped = kept.toString().trim();
    return clipped.isEmpty ? null : clipped;
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
    // Rows without the column (older selects) count as visible.
    isModerated: (row['moderation_status'] ?? 'visible') != 'visible',
  );
}
