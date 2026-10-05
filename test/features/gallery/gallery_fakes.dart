import 'dart:io';

import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/gallery/data/gallery_photo_picker.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/i_cafe_picker_source.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/gallery_flows.dart';

/// A gallery photo with sensible defaults. Images are local paths that do
/// not exist, so tiles draw their "could not load" placeholder without any
/// network.
GalleryPhoto galleryPhoto(
  String id, {
  String cafeId = 'cafe-1',
  String cafeName = 'Kamp Craft Coffee',
  String? drink,
  DateTime? takenAt,
  GalleryPhotoSource source = GalleryPhotoSource.gallery,
  bool hidden = false,
  int? pin,
}) {
  return GalleryPhoto(
    id: id,
    userId: 'me',
    cafeId: cafeId,
    cafeName: cafeName,
    cafeArea: 'Camputhaw, Cebu City',
    imageUrl: '/nonexistent/$id.jpg',
    drinkName: drink,
    takenAt: takenAt ?? DateTime(2026, 3, 14),
    source: source,
    sourceId: source == GalleryPhotoSource.review ? 'review-1' : null,
    isHidden: hidden,
    pinOrder: pin,
  );
}

CafeSummary cafeSummary(String id, String name, {String? neighborhood}) =>
    CafeSummary(
      id: id,
      name: name,
      neighborhood: neighborhood ?? 'Lahug',
      city: 'Cebu City',
      rating: 4.5,
    );

/// In-memory repository that records writes and can be told to fail.
class FakeGalleryRepository implements IGalleryRepository {
  FakeGalleryRepository([List<GalleryPhoto>? photos]) : photos = [...?photos];

  List<GalleryPhoto> photos;
  Object? readFailure;
  Object? writeFailure;
  final List<String> calls = [];
  final List<
    ({String cafeId, int count, GalleryPhotoSource source, String? drink})
  >
  added = [];

  void _write(String call) {
    calls.add(call);
    final failure = writeFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<List<GalleryPhoto>> getMyPhotos() async {
    final failure = readFailure;
    if (failure != null) throw failure;
    return List.of(photos);
  }

  @override
  Future<List<GalleryPhoto>> addPhotos({
    required String cafeId,
    required List<PickedGalleryPhoto> photos,
    required GalleryPhotoSource source,
    String? drinkName,
  }) async {
    _write('add');
    added.add((
      cafeId: cafeId,
      count: photos.length,
      source: source,
      drink: drinkName,
    ));
    final rows = [
      for (var i = 0; i < photos.length; i++)
        galleryPhoto(
          'new-${this.photos.length + i}',
          cafeId: cafeId,
          drink: drinkName,
          takenAt: photos[i].takenAt ?? DateTime(2026, 10, 5),
          source: source,
        ),
    ];
    this.photos.addAll(rows);
    return rows;
  }

  @override
  Future<void> setPinOrder(String photoId, int? pinOrder) async =>
      _write('pin $photoId $pinOrder');

  @override
  Future<void> setHidden(String photoId, {required bool hidden}) async =>
      _write('hide $photoId $hidden');

  @override
  Future<void> setDrinkName(String photoId, String? drinkName) async =>
      _write('drink $photoId $drinkName');

  @override
  Future<void> deletePhoto(String photoId) async => _write('delete $photoId');
}

class FakeCafePickerSource implements ICafePickerSource {
  FakeCafePickerSource({
    this.been = const [],
    this.near,
    this.nearAfterAsking,
    this.match,
    this.results = const {},
  });

  final List<CafeSummary> been;

  /// Null: location not allowed.
  final List<CafeSummary>? near;

  /// What nearby() returns once "Use my location" was tapped.
  final List<CafeSummary>? nearAfterAsking;
  final CafeSummary? match;
  final Map<String, List<CafeSummary>> results;
  final List<String> searches = [];
  final List<(double, double)> takenAtCalls = [];
  int asks = 0;

  @override
  Future<List<CafeSummary>> beenCafes() async => been;

  @override
  Future<List<CafeSummary>?> nearby({bool ask = false}) async {
    if (ask) {
      asks++;
      return nearAfterAsking;
    }
    return near;
  }

  @override
  Future<CafeSummary?> takenAt(
    double lat,
    double lng, {
    double maxMeters = 150,
  }) async {
    takenAtCalls.add((lat, lng));
    return match;
  }

  @override
  Future<List<CafeSummary>> search(String query) async {
    searches.add(query);
    return results[query.toLowerCase()] ?? const [];
  }
}

/// Returns canned photos instead of opening the system picker.
class FakeGalleryPhotoPicker implements GalleryPhotoPicker {
  FakeGalleryPhotoPicker({this.many = const [], this.one});

  List<PickedGalleryPhoto> many;
  PickedGalleryPhoto? one;
  int cameraCalls = 0;
  int libraryCalls = 0;

  @override
  Future<List<PickedGalleryPhoto>> pickMany() async => many;

  @override
  Future<PickedGalleryPhoto?> pickOne() async {
    libraryCalls++;
    return one;
  }

  @override
  Future<PickedGalleryPhoto?> takePhoto() async {
    cameraCalls++;
    return one;
  }
}

PickedGalleryPhoto pickedPhoto(
  String name, {
  double? lat,
  double? lng,
  DateTime? takenAt,
}) => PickedGalleryPhoto(
  file: File('/nonexistent/$name.jpg'),
  latitude: lat,
  longitude: lng,
  takenAt: takenAt,
);

GalleryFlowDeps galleryDeps({
  required GalleryCubit cubit,
  GalleryPhotoPicker? picker,
  ICafePickerSource? cafes,
}) => GalleryFlowDeps(
  cubit: cubit,
  picker: picker ?? FakeGalleryPhotoPicker(),
  cafes: cafes ?? FakeCafePickerSource(),
);
