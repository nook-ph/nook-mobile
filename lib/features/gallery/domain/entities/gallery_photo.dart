import 'dart:io';

import 'package:equatable/equatable.dart';

/// The longest note on a photo (`user_photos.caption`).
const maxGalleryCaption = 150;

/// Where a gallery photo came from (`user_photos.source`).
enum GalleryPhotoSource {
  /// Added on the ranking reveal, right after marking a cafe Been.
  rank('rank'),

  /// One of the photos of a review. Managed through the review: it can be
  /// pinned or hidden here, but not deleted.
  review('review'),

  /// Added with + on the Gallery tab.
  gallery('gallery'),

  /// Reserved for crawl-stop photos; nothing writes it in v1.
  crawl('crawl');

  const GalleryPhotoSource(this.wire);

  final String wire;

  static GalleryPhotoSource fromWire(String? value) =>
      GalleryPhotoSource.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => GalleryPhotoSource.gallery,
      );
}

/// One cup in a person's coffee gallery. Every photo belongs to a cafe
/// (spec: nook-supabase docs/COFFEE_GALLERY.md).
class GalleryPhoto extends Equatable {
  const GalleryPhoto({
    required this.id,
    required this.userId,
    required this.cafeId,
    required this.cafeName,
    required this.imageUrl,
    required this.takenAt,
    required this.source,
    this.cafeArea,
    this.drinkName,
    this.caption,
    this.sourceId,
    this.isHidden = false,
    this.pinOrder,
  });

  final String id;
  final String userId;
  final String cafeId;
  final String cafeName;

  /// "Lahug, Cebu City", for the viewer's cafe chip.
  final String? cafeArea;

  /// The public image. A local file path only in the debug fake.
  final String imageUrl;

  /// "Iced Spanish latte". Optional.
  final String? drinkName;

  /// The owner's note on this cup, up to [maxGalleryCaption] characters.
  /// Optional; review photos have none (the review text stands in).
  final String? caption;

  /// From the photo's EXIF when the device had it, else when it was added.
  final DateTime takenAt;
  final GalleryPhotoSource source;

  /// The review id for [GalleryPhotoSource.review].
  final String? sourceId;

  /// Hidden from the profile; only the owner sees it.
  final bool isHidden;

  /// 1–3 when pinned to the top of the gallery.
  final int? pinOrder;

  bool get isPinned => pinOrder != null;
  bool get isFromReview => source == GalleryPhotoSource.review;

  GalleryPhoto copyWith({
    String? drinkName,
    bool clearDrinkName = false,
    String? caption,
    bool clearCaption = false,
    bool? isHidden,
    int? pinOrder,
    bool clearPin = false,
  }) {
    return GalleryPhoto(
      id: id,
      userId: userId,
      cafeId: cafeId,
      cafeName: cafeName,
      cafeArea: cafeArea,
      imageUrl: imageUrl,
      drinkName: clearDrinkName ? null : (drinkName ?? this.drinkName),
      caption: clearCaption ? null : (caption ?? this.caption),
      takenAt: takenAt,
      source: source,
      sourceId: sourceId,
      isHidden: isHidden ?? this.isHidden,
      pinOrder: clearPin ? null : (pinOrder ?? this.pinOrder),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    cafeId,
    cafeName,
    cafeArea,
    imageUrl,
    drinkName,
    caption,
    takenAt,
    source,
    sourceId,
    isHidden,
    pinOrder,
  ];
}

/// A photo picked on the device, ready to upload. [takenAt] and the
/// coordinates come from its EXIF before it is re-encoded; the coordinates
/// are only used on the device to suggest a cafe and are never uploaded.
class PickedGalleryPhoto extends Equatable {
  const PickedGalleryPhoto({
    required this.file,
    this.takenAt,
    this.latitude,
    this.longitude,
  });

  final File file;
  final DateTime? takenAt;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  @override
  List<Object?> get props => [file.path, takenAt, latitude, longitude];
}
