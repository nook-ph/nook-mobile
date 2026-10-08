import 'package:flutter/foundation.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';

/// How a debug build runs the gallery, from
/// `--dart-define=GALLERY_DEMO=photos|empty`. Release builds ignore it.
///
/// `user_photos` is not in production yet, so without this the Gallery tab
/// can only show its error state. The demo keeps everything in memory: it
/// reads cafes (to have real names and pictures) and writes nothing, so
/// trying the flows on a device never touches production data or storage.
enum GalleryDemoMode {
  off,
  photos,
  empty;

  static GalleryDemoMode get current {
    if (!kDebugMode) return off;
    return switch (const String.fromEnvironment('GALLERY_DEMO')) {
      'photos' => photos,
      'empty' => empty,
      _ => off,
    };
  }
}

/// In-memory [IGalleryRepository] for the debug demo. Added photos keep
/// their local file path as the image.
class DemoGalleryRepository implements IGalleryRepository {
  DemoGalleryRepository({
    required Future<List<CafeSummary>> Function() cafes,
    bool seed = true,
  }) : _cafes = cafes,
       _seed = seed;

  final Future<List<CafeSummary>> Function() _cafes;
  final bool _seed;
  List<GalleryPhoto>? _photos;
  var _nextId = 0;

  static const _drinks = [
    'Iced Spanish latte',
    'Flat white',
    null,
    'Batch brew, Ethiopia Guji',
    'Sea salt cold brew',
    null,
    'Cortado',
    'Ube latte',
  ];

  static const _notes = [
    'Too sweet for me, but the foam held up the whole way down.',
    'Rainy Tuesday, stayed three hours. Not too sweet, the espresso still '
        'comes through, and they topped up the ice twice. Best one in Lahug.',
    'Light roast, tastes like strawberries.',
  ];

  Future<List<GalleryPhoto>> _all() async {
    final existing = _photos;
    if (existing != null) return existing;
    final photos = <GalleryPhoto>[];
    if (_seed) {
      final cafes = await _cafes();
      final now = DateTime.now();
      var n = 0;
      for (final cafe in cafes) {
        final images = {
          ?cafe.coverImage,
          ...cafe.photoUrls,
        }.where((u) => u.startsWith('http')).take(3);
        for (final url in images) {
          photos.add(
            GalleryPhoto(
              id: 'demo-${n++}',
              userId: 'demo',
              cafeId: cafe.id,
              cafeName: cafe.name,
              cafeArea: cafe.locationLabel.isEmpty ? null : cafe.locationLabel,
              imageUrl: url,
              drinkName: _drinks[n % _drinks.length],
              caption: n % 3 == 0 ? _notes[n % _notes.length] : null,
              takenAt: now.subtract(Duration(days: n * 9)),
              source: n % 5 == 0
                  ? GalleryPhotoSource.review
                  : GalleryPhotoSource.gallery,
              sourceId: n % 5 == 0 ? 'demo-review' : null,
              pinOrder: n == 4 ? 1 : (n == 7 ? 2 : null),
              isHidden: n == 6,
            ),
          );
        }
      }
    }
    return _photos = photos;
  }

  @override
  Future<List<GalleryPhoto>> getMyPhotos() async => List.of(await _all());

  @override
  Future<List<GalleryPhoto>> addPhotos({
    required String cafeId,
    required List<PickedGalleryPhoto> photos,
    required GalleryPhotoSource source,
    String? drinkName,
    String? caption,
  }) async {
    final all = await _all();
    final cafes = await _cafes();
    final cafe = cafes.where((c) => c.id == cafeId).firstOrNull;
    // Long enough to see the sheet's saving state.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final added = [
      for (final photo in photos)
        GalleryPhoto(
          id: 'demo-new-${_nextId++}',
          userId: 'demo',
          cafeId: cafeId,
          cafeName: cafe?.name ?? 'Cafe',
          cafeArea: cafe?.locationLabel,
          imageUrl: photo.file.path,
          drinkName: drinkName,
          caption: caption,
          takenAt: photo.takenAt ?? DateTime.now(),
          source: source,
        ),
    ];
    all.addAll(added);
    return added;
  }

  void _replace(String id, GalleryPhoto Function(GalleryPhoto) change) {
    final all = _photos ?? [];
    final i = all.indexWhere((p) => p.id == id);
    if (i >= 0) all[i] = change(all[i]);
  }

  @override
  Future<void> setPinOrder(String photoId, int? pinOrder) async => _replace(
    photoId,
    (p) => pinOrder == null
        ? p.copyWith(clearPin: true)
        : p.copyWith(pinOrder: pinOrder),
  );

  @override
  Future<void> setHidden(String photoId, {required bool hidden}) async =>
      _replace(
        photoId,
        (p) => hidden
            ? p.copyWith(isHidden: true, clearPin: true)
            : p.copyWith(isHidden: false),
      );

  @override
  Future<void> setDetails(
    String photoId, {
    String? drinkName,
    String? caption,
    String? cafeId,
  }) async => _replace(
    photoId,
    (p) => p.copyWith(
      drinkName: drinkName,
      clearDrinkName: drinkName == null,
      caption: caption,
      clearCaption: caption == null,
    ),
  );

  @override
  Future<void> deletePhoto(String photoId) async =>
      _photos?.removeWhere((p) => p.id == photoId);
}
