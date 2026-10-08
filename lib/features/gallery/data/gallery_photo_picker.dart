import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nook/core/utils/compressed_image_target.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';

/// The most photos one + adds at a time.
const maxGalleryBatch = 10;

/// Picks photos for the gallery and readies them for upload: reads each
/// one's EXIF date and position on the device, then re-encodes it, which
/// drops all EXIF. Uploads are public-read, so a photo's GPS must never
/// leave the phone (docs/ux/coffee-gallery.md, finding 1).
class GalleryPhotoPicker {
  GalleryPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// One photo from the camera. Null when cancelled.
  Future<PickedGalleryPhoto?> takePhoto() async {
    final shot = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (shot == null) return null;
    return _prepare(File(shot.path), fromCamera: true);
  }

  /// One photo from the library. Null when cancelled.
  Future<PickedGalleryPhoto?> pickOne() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return _prepare(File(picked.path));
  }

  /// Up to [maxGalleryBatch] photos from the library. Empty when cancelled.
  Future<List<PickedGalleryPhoto>> pickMany() async {
    final picked = await _picker.pickMultiImage(limit: maxGalleryBatch);
    final files = picked.take(maxGalleryBatch).map((x) => File(x.path));
    return Future.wait([for (final file in files) _prepare(file)]);
  }

  Future<PickedGalleryPhoto> _prepare(
    File source, {
    bool fromCamera = false,
  }) async {
    final meta = await readPhotoMeta(source);
    final clean = await _reencode(source);
    return PickedGalleryPhoto(
      file: clean,
      // A camera shot is taken now even if the plugin wrote no EXIF.
      takenAt: meta.takenAt ?? (fromCamera ? DateTime.now() : null),
      latitude: meta.lat,
      longitude: meta.lng,
    );
  }

  /// JPEG at 85, longest side 2048. `keepExif` stays false.
  static Future<File> _reencode(File file) async {
    final target = compressedImageTarget(file.path);
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      target.path,
      quality: 85,
      minWidth: 2048,
      minHeight: 2048,
      format: target.isPng ? CompressFormat.png : CompressFormat.jpeg,
    );
    if (result == null) {
      throw const FileSystemException('Could not prepare the photo.');
    }
    return File(result.path);
  }
}

/// A photo's EXIF capture time and position, when it has them.
typedef PhotoMeta = ({DateTime? takenAt, double? lat, double? lng});

Future<PhotoMeta> readPhotoMeta(File file) async {
  try {
    final tags = await readExifFromBytes(await file.readAsBytes());
    return parsePhotoMeta(tags);
  } catch (_) {
    // Unreadable EXIF is the same as none: the date falls back to now and
    // the cafe suggestion is skipped.
    return (takenAt: null, lat: null, lng: null);
  }
}

/// Pulls the capture time and position out of [tags]. Public for tests.
@visibleForTesting
PhotoMeta parsePhotoMeta(Map<String, IfdTag> tags) {
  return (
    takenAt: parseExifDate(
      (tags['EXIF DateTimeOriginal'] ?? tags['Image DateTime'])?.printable,
    ),
    lat: _coordinate(tags['GPS GPSLatitude'], tags['GPS GPSLatitudeRef']),
    lng: _coordinate(tags['GPS GPSLongitude'], tags['GPS GPSLongitudeRef']),
  );
}

/// "2026:03:14 09:41:07" (EXIF's local-time format) to a DateTime.
@visibleForTesting
DateTime? parseExifDate(String? raw) {
  final match = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(raw?.trim() ?? '');
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  if (parts[0] < 1990 || parts[1] == 0 || parts[2] == 0) return null;
  final date = DateTime(
    parts[0],
    parts[1],
    parts[2],
    parts[3],
    parts[4],
    parts[5],
  );
  // A clock set wrong can say the photo is from the future.
  return date.isAfter(DateTime.now().add(const Duration(days: 1)))
      ? null
      : date;
}

double? _coordinate(IfdTag? value, IfdTag? ref) {
  if (value == null) return null;
  final parts = value.values.toList();
  if (parts.length < 3) return null;
  double part(Object? v) => v is Ratio ? v.toDouble() : (v as num).toDouble();
  final degrees = part(parts[0]) + part(parts[1]) / 60 + part(parts[2]) / 3600;
  final negative = const {'S', 'W'}.contains(ref?.printable.trim());
  final result = negative ? -degrees : degrees;
  // 0,0 is what some apps write for "no location".
  return result == 0 ? null : result;
}
