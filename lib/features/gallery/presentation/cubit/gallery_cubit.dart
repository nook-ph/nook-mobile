import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';

enum GalleryStatus { initial, loading, loaded, failed }

/// The most photos that can be pinned to the top of a gallery.
const maxGalleryPins = 3;

/// What a pin tap did.
enum PinOutcome { pinned, unpinned, full, failed }

/// A photo on its way into the gallery. The grid shows it with a progress
/// bar until its row lands, or with Retry when it failed (Figma E2).
class GalleryUpload extends Equatable {
  const GalleryUpload({
    required this.id,
    required this.photo,
    required this.cafeId,
    required this.source,
    this.drinkName,
    this.caption,
    this.failed = false,
  });

  /// Local only; never a `user_photos` id.
  final String id;
  final PickedGalleryPhoto photo;
  final String cafeId;
  final GalleryPhotoSource source;
  final String? drinkName;
  final String? caption;
  final bool failed;

  GalleryUpload copyWith({required bool failed}) => GalleryUpload(
    id: id,
    photo: photo,
    cafeId: cafeId,
    source: source,
    drinkName: drinkName,
    caption: caption,
    failed: failed,
  );

  @override
  List<Object?> get props => [
    id,
    photo,
    cafeId,
    source,
    drinkName,
    caption,
    failed,
  ];
}

class GalleryState extends Equatable {
  const GalleryState({
    this.status = GalleryStatus.initial,
    this.photos = const [],
    this.uploads = const [],
  });

  final GalleryStatus status;

  /// Pinned first (slot 1–3), then newest first.
  final List<GalleryPhoto> photos;

  /// Photos still uploading, or failed and waiting for Retry, in the order
  /// they were added.
  final List<GalleryUpload> uploads;

  Iterable<GalleryPhoto> get _shown =>
      photos.where((p) => !p.isHidden && !p.isModerated);

  /// Photos visitors can see: the "cups" in the header.
  int get cupCount => _shown.length;

  /// Distinct cafes among the photos visitors can see.
  int get cafeCount => _shown.map((p) => p.cafeId).toSet().length;

  int get hiddenCount => photos.length - cupCount;
  int get pinnedCount => photos.where((p) => p.isPinned).length;

  GalleryState copyWith({
    GalleryStatus? status,
    List<GalleryPhoto>? photos,
    List<GalleryUpload>? uploads,
  }) => GalleryState(
    status: status ?? this.status,
    photos: photos == null ? this.photos : sortGallery(photos),
    uploads: uploads == null ? this.uploads : List.unmodifiable(uploads),
  );

  @override
  List<Object?> get props => [status, photos, uploads];
}

/// Pinned photos by slot, then the rest newest first.
List<GalleryPhoto> sortGallery(Iterable<GalleryPhoto> photos) {
  final list = photos.toList();
  list.sort((a, b) {
    final pa = a.pinOrder, pb = b.pinOrder;
    if (pa != null && pb != null) return pa.compareTo(pb);
    if (pa != null) return -1;
    if (pb != null) return 1;
    final byDate = b.takenAt.compareTo(a.takenAt);
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  });
  return List.unmodifiable(list);
}

/// The signed-in person's coffee gallery. App-wide, so a photo added on the
/// ranking reveal is already on the profile when they get there.
///
/// Edits are optimistic: the grid changes at once and goes back if the
/// write fails, and the method reports the failure so the caller can say so.
class GalleryCubit extends Cubit<GalleryState> {
  GalleryCubit({required IGalleryRepository repository})
    : _repository = repository,
      super(const GalleryState());

  final IGalleryRepository _repository;

  /// A write landed while a load was in flight; that load's read may predate
  /// it, so load again when it finishes.
  bool _reloadAfterLoad = false;

  /// Loads the gallery. [refresh] keeps what is shown while it reloads.
  Future<void> load({bool refresh = false}) async {
    if (state.status == GalleryStatus.loading) return;
    if (!refresh || state.status != GalleryStatus.loaded) {
      emit(state.copyWith(status: GalleryStatus.loading));
    }
    _reloadAfterLoad = false;
    try {
      final photos = await _repository.getMyPhotos();
      if (isClosed) return;
      // Uploads in flight stay: they are not rows yet.
      emit(state.copyWith(status: GalleryStatus.loaded, photos: photos));
    } catch (_) {
      if (isClosed) return;
      // A failed refresh keeps the photos already on screen.
      if (refresh && state.photos.isNotEmpty) {
        emit(state.copyWith(status: GalleryStatus.loaded));
      } else {
        emit(state.copyWith(status: GalleryStatus.failed));
      }
    }
    if (_reloadAfterLoad && !isClosed) {
      _reloadAfterLoad = false;
      await load(refresh: true);
    }
  }

  /// Uploads and adds [photos] to [cafeId]. Throws when the upload or the
  /// save fails, so the sheet that asked can offer to try again.
  Future<List<GalleryPhoto>> addPhotos({
    required String cafeId,
    required List<PickedGalleryPhoto> photos,
    required GalleryPhotoSource source,
    String? drinkName,
    String? caption,
  }) async {
    final added = await _repository.addPhotos(
      cafeId: cafeId,
      photos: photos,
      source: source,
      drinkName: drinkName,
      caption: caption,
    );
    logAppEvent(
      ProfileEvents.galleryPhotosAdded,
      properties: {
        'count': added.length,
        'source': source.wire,
        'has_drink': (drinkName?.trim() ?? '').isNotEmpty,
        'has_note': (caption?.trim() ?? '').isNotEmpty,
      },
    );
    if (isClosed) return added;
    switch (state.status) {
      case GalleryStatus.loaded:
        emit(state.copyWith(photos: [...state.photos, ...added]));
      case GalleryStatus.loading:
        // The read in flight may have started before this save.
        _reloadAfterLoad = true;
      case GalleryStatus.initial:
      case GalleryStatus.failed:
        // Never loaded (e.g. a photo added on the ranking reveal before the
        // Profile tab opened): showing only [added] would hide the rest of
        // the gallery, so load all of it.
        unawaited(load());
    }
    return added;
  }

  var _uploadSeq = 0;

  /// Starts adding [photos] to [cafeId] and returns at once, so the sheet
  /// that asked can close. Each photo shows in the grid as a
  /// [GalleryUpload] until its row lands, or fails and offers Retry. The
  /// future completes when every photo has landed or failed.
  Future<({int added, int failed})> upload({
    required String cafeId,
    required List<PickedGalleryPhoto> photos,
    required GalleryPhotoSource source,
    String? drinkName,
    String? caption,
  }) async {
    final batch = [
      for (final photo in photos)
        GalleryUpload(
          id: 'upload-${_uploadSeq++}',
          photo: photo,
          cafeId: cafeId,
          source: source,
          drinkName: drinkName,
          caption: caption,
        ),
    ];
    emit(state.copyWith(uploads: [...state.uploads, ...batch]));
    final results = await Future.wait(batch.map(_send));
    final added = results.where((ok) => ok).length;
    if (added > 0) {
      logAppEvent(
        ProfileEvents.galleryPhotosAdded,
        properties: {
          'count': added,
          'source': source.wire,
          'has_drink': (drinkName?.trim() ?? '').isNotEmpty,
          'has_note': (caption?.trim() ?? '').isNotEmpty,
        },
      );
    }
    return (added: added, failed: results.length - added);
  }

  /// Sends a failed upload again. Does nothing while it is already going,
  /// so a second tap on Retry never adds the photo twice.
  Future<bool> retryUpload(String id) async {
    final upload = state.uploads.where((u) => u.id == id).firstOrNull;
    if (upload == null || !upload.failed) return false;
    final again = upload.copyWith(failed: false);
    _replaceUpload(again);
    return _send(again);
  }

  /// Drops a failed upload from the grid.
  void discardUpload(String id) {
    final upload = state.uploads.where((u) => u.id == id).firstOrNull;
    if (upload == null || !upload.failed) return;
    emit(
      state.copyWith(
        uploads: [
          for (final u in state.uploads)
            if (u.id != id) u,
        ],
      ),
    );
  }

  Future<bool> _send(GalleryUpload upload) async {
    try {
      final rows = await _repository.addPhotos(
        cafeId: upload.cafeId,
        photos: [upload.photo],
        source: upload.source,
        drinkName: upload.drinkName,
        caption: upload.caption,
      );
      // Signed out meanwhile: the row is saved; this gallery is not theirs.
      if (isClosed || !state.uploads.any((u) => u.id == upload.id)) {
        return true;
      }
      final rest = [
        for (final u in state.uploads)
          if (u.id != upload.id) u,
      ];
      if (state.status == GalleryStatus.loaded) {
        emit(state.copyWith(photos: [...state.photos, ...rows], uploads: rest));
      } else {
        emit(state.copyWith(uploads: rest));
        await load();
      }
      return true;
    } catch (_) {
      if (!isClosed && state.uploads.any((u) => u.id == upload.id)) {
        _replaceUpload(upload.copyWith(failed: true));
      }
      return false;
    }
  }

  void _replaceUpload(GalleryUpload next) => emit(
    state.copyWith(
      uploads: [for (final u in state.uploads) u.id == next.id ? next : u],
    ),
  );

  /// Pins [photo] to the first free slot, or unpins it.
  Future<PinOutcome> togglePin(GalleryPhoto photo) async {
    if (photo.isPinned) {
      final ok = await _apply(
        photo.copyWith(clearPin: true),
        () => _repository.setPinOrder(photo.id, null),
      );
      return ok ? PinOutcome.unpinned : PinOutcome.failed;
    }
    // Visitors can't see it, so a pin would only use up a slot.
    if (photo.isModerated) return PinOutcome.failed;
    final used = state.photos.map((p) => p.pinOrder).whereType<int>().toSet();
    final free = [
      for (var slot = 1; slot <= maxGalleryPins; slot++)
        if (!used.contains(slot)) slot,
    ];
    if (free.isEmpty) return PinOutcome.full;
    final ok = await _apply(
      photo.copyWith(pinOrder: free.first),
      () => _repository.setPinOrder(photo.id, free.first),
    );
    return ok ? PinOutcome.pinned : PinOutcome.failed;
  }

  /// Hides [photo] from the profile (it stays for the owner), or shows it
  /// again. Hiding also unpins it. Returns false when the write failed.
  Future<bool> setHidden(GalleryPhoto photo, {required bool hidden}) {
    return _apply(
      hidden
          ? photo.copyWith(isHidden: true, clearPin: true)
          : photo.copyWith(isHidden: false),
      () => _repository.setHidden(photo.id, hidden: hidden),
    );
  }

  /// Sets the drink and the note; empty text clears either. A [cafe]
  /// other than the photo's moves it there (not a review photo's).
  Future<bool> setDetails(
    GalleryPhoto photo, {
    String? drinkName,
    String? caption,
    PickedCafe? cafe,
  }) {
    String? clean(String? v) => (v?.trim().isEmpty ?? true) ? null : v!.trim();
    final drink = clean(drinkName), note = clean(caption);
    final move = cafe != null && cafe.id != photo.cafeId && !photo.isFromReview
        ? cafe
        : null;
    return _apply(
      photo.copyWith(
        drinkName: drink,
        clearDrinkName: drink == null,
        caption: note,
        clearCaption: note == null,
        cafe: move == null
            ? null
            : (id: move.id, name: move.name, area: move.area),
      ),
      () => _repository.setDetails(
        photo.id,
        drinkName: drink,
        caption: note,
        cafeId: move?.id,
      ),
    );
  }

  /// Deletes [photo]. Review photos are refused: they belong to the review.
  Future<bool> delete(GalleryPhoto photo) async {
    if (photo.isFromReview) return false;
    final before = state.photos;
    emit(
      state.copyWith(
        photos: [
          for (final p in before)
            if (p.id != photo.id) p,
        ],
      ),
    );
    try {
      await _repository.deletePhoto(photo.id);
      return true;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(photos: before));
      return false;
    }
  }

  /// Signed out: forget the photos.
  void clear() => emit(const GalleryState());

  Future<bool> _apply(GalleryPhoto next, Future<void> Function() write) async {
    final before = state.photos;
    emit(
      state.copyWith(
        photos: [for (final p in before) p.id == next.id ? next : p],
      ),
    );
    try {
      await write();
      return true;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(photos: before));
      return false;
    }
  }
}
