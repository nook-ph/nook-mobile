import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/domain/i_community_photos_repository.dart';

enum CafePhotosStatus { initial, loading, loaded, failed }

class CafePhotosState extends Equatable {
  const CafePhotosState({
    this.status = CafePhotosStatus.initial,
    this.photos = const [],
    this.total = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.nextOffset = 0,
    this.error,
  });

  final CafePhotosStatus status;
  final List<CommunityPhoto> photos;

  /// Every photo of the cafe the viewer may see.
  final int total;
  final bool hasMore;
  final bool loadingMore;

  /// The next page failed; the photos already shown stay.
  final bool loadMoreFailed;

  /// Where the next page starts, in rows ([CommunityPhotoPage.nextOffset]).
  final int nextOffset;

  /// The first load's failure, for [AppErrorCopy].
  final Object? error;

  bool get isEmpty => status == CafePhotosStatus.loaded && photos.isEmpty;

  CafePhotosState copyWith({
    CafePhotosStatus? status,
    List<CommunityPhoto>? photos,
    int? total,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
    int? nextOffset,
    Object? error,
  }) => CafePhotosState(
    status: status ?? this.status,
    photos: photos ?? this.photos,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    nextOffset: nextOffset ?? this.nextOffset,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    photos,
    total,
    hasMore,
    loadingMore,
    loadMoreFailed,
    nextOffset,
    error,
  ];
}

/// A cafe's community photos, a page at a time. The details strip loads
/// one small page and never more; the "See all" grid starts from the
/// strip's photos ([seed]) and pages on as it scrolls.
class CafePhotosCubit extends Cubit<CafePhotosState> {
  CafePhotosCubit({
    required ICommunityPhotosRepository repository,
    required this.cafeId,
    this.pageSize = stripPageSize,
    CafePhotosState? seed,
  }) : _repository = repository,
       super(seed ?? const CafePhotosState());

  /// Enough to fill the strip past the screen edge, and to know whether
  /// "See all" has more to show.
  static const stripPageSize = 8;

  /// One grid page: a few screens of the two-column grid.
  static const gridPageSize = 24;

  final ICommunityPhotosRepository _repository;
  final String cafeId;
  final int pageSize;

  /// Bumped by every [load], so a page that lands after a reload is dropped.
  int _epoch = 0;

  /// Loads the first page. [refresh] keeps what is shown while it reloads
  /// (after the viewer adds a photo).
  Future<void> load({bool refresh = false}) async {
    final epoch = ++_epoch;
    if (!refresh || state.status != CafePhotosStatus.loaded) {
      emit(const CafePhotosState(status: CafePhotosStatus.loading));
    }
    try {
      final page = await _repository.getCafePhotos(cafeId, limit: pageSize);
      if (isClosed || epoch != _epoch) return;
      emit(
        CafePhotosState(
          status: CafePhotosStatus.loaded,
          photos: List.unmodifiable(page.photos),
          total: page.total,
          hasMore: page.hasMore,
          nextOffset: page.nextOffset,
        ),
      );
    } catch (e) {
      debugPrint('[CafePhotos] load failed cafeId=$cafeId error=$e');
      if (isClosed || epoch != _epoch) return;
      if (refresh && state.status == CafePhotosStatus.loaded) return;
      emit(CafePhotosState(status: CafePhotosStatus.failed, error: e));
    }
  }

  /// The next page, for the grid. Does nothing while one is on its way or
  /// when there is no more.
  Future<void> loadMore() async {
    final current = state;
    if (current.status != CafePhotosStatus.loaded ||
        !current.hasMore ||
        current.loadingMore) {
      return;
    }
    final epoch = _epoch;
    emit(current.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await _repository.getCafePhotos(
        cafeId,
        limit: pageSize,
        offset: current.nextOffset,
      );
      if (isClosed || epoch != _epoch) return;
      // A photo added since the first page shifts the rest by one; the
      // repeat it causes is dropped by id.
      final seen = {for (final p in current.photos) p.id};
      emit(
        state.copyWith(
          photos: List.unmodifiable([
            ...current.photos,
            ...page.photos.where((p) => !seen.contains(p.id)),
          ]),
          total: page.total,
          hasMore: page.hasMore,
          nextOffset: page.nextOffset,
          loadingMore: false,
        ),
      );
    } catch (e) {
      debugPrint('[CafePhotos] loadMore failed cafeId=$cafeId error=$e');
      if (isClosed || epoch != _epoch) return;
      emit(state.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }
}
