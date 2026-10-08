import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';

enum GalleryStatus { initial, loading, loaded, failed }

/// The most photos that can be pinned to the top of a gallery.
const maxGalleryPins = 3;

/// What a pin tap did.
enum PinOutcome { pinned, unpinned, full, failed }

class GalleryState extends Equatable {
  const GalleryState({
    this.status = GalleryStatus.initial,
    this.photos = const [],
  });

  final GalleryStatus status;

  /// Pinned first (slot 1–3), then newest first.
  final List<GalleryPhoto> photos;

  Iterable<GalleryPhoto> get _shown => photos.where((p) => !p.isHidden);

  /// Photos visitors can see: the "cups" in the header.
  int get cupCount => _shown.length;

  /// Distinct cafes among the photos visitors can see.
  int get cafeCount => _shown.map((p) => p.cafeId).toSet().length;

  int get hiddenCount => photos.length - cupCount;
  int get pinnedCount => photos.where((p) => p.isPinned).length;

  GalleryState copyWith({GalleryStatus? status, List<GalleryPhoto>? photos}) =>
      GalleryState(
        status: status ?? this.status,
        photos: photos == null ? this.photos : sortGallery(photos),
      );

  @override
  List<Object?> get props => [status, photos];
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
      emit(
        GalleryState(status: GalleryStatus.loaded, photos: sortGallery(photos)),
      );
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

  /// Pins [photo] to the first free slot, or unpins it.
  Future<PinOutcome> togglePin(GalleryPhoto photo) async {
    if (photo.isPinned) {
      final ok = await _apply(
        photo.copyWith(clearPin: true),
        () => _repository.setPinOrder(photo.id, null),
      );
      return ok ? PinOutcome.unpinned : PinOutcome.failed;
    }
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

  /// Sets the drink and the note; empty text clears either.
  Future<bool> setDetails(
    GalleryPhoto photo, {
    String? drinkName,
    String? caption,
  }) {
    String? clean(String? v) => (v?.trim().isEmpty ?? true) ? null : v!.trim();
    final drink = clean(drinkName), note = clean(caption);
    return _apply(
      photo.copyWith(
        drinkName: drink,
        clearDrinkName: drink == null,
        caption: note,
        clearCaption: note == null,
      ),
      () => _repository.setDetails(photo.id, drinkName: drink, caption: note),
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
