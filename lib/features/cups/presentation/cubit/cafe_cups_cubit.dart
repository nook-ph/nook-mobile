import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';

enum CafeCupsStatus { initial, loading, loaded, failed }

class CafeCupsState extends Equatable {
  const CafeCupsState({
    this.status = CafeCupsStatus.initial,
    this.stats = const CupStats(),
    this.cards = const [],
    this.total = 0,
    this.hasMore = false,
    this.sort = CupSort.recommended,
    this.ratingFilter,
    this.kind,
    this.loadingMore = false,
    this.loadMoreFailed = false,
    this.mode = CupsMode.unknown,
    this.myCups = const [],
    this.error,
  });

  final CafeCupsStatus status;

  /// The whole cafe's numbers, whatever the filter.
  final CupStats stats;

  /// Loaded so far, in [sort] order, matching [ratingFilter].
  final List<CupCard> cards;

  /// Every card matching [ratingFilter].
  final int total;
  final bool hasMore;
  final CupSort sort;
  final int? ratingFilter;

  /// Only cups with an item of this kind; null is All.
  final CupItemKind? kind;
  final bool loadingMore;
  final bool loadMoreFailed;

  /// Which backend answered; [CupsMode.legacy] needs stars with a note.
  final CupsMode mode;

  /// Your own cups here, newest first, for the composer's "Your last cup
  /// here".
  final List<CupCard> myCups;
  final Object? error;

  bool get isLoaded => status == CafeCupsStatus.loaded;

  bool get isFiltered => ratingFilter != null || kind != null;

  CafeCupsState copyWith({
    CafeCupsStatus? status,
    CupStats? stats,
    List<CupCard>? cards,
    int? total,
    bool? hasMore,
    CupSort? sort,
    int? ratingFilter,
    bool clearFilter = false,
    CupItemKind? kind,
    bool clearKind = false,
    bool? loadingMore,
    bool? loadMoreFailed,
    CupsMode? mode,
    List<CupCard>? myCups,
    Object? error,
  }) => CafeCupsState(
    status: status ?? this.status,
    stats: stats ?? this.stats,
    cards: cards ?? this.cards,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    sort: sort ?? this.sort,
    ratingFilter: clearFilter ? null : (ratingFilter ?? this.ratingFilter),
    kind: clearKind ? null : (kind ?? this.kind),
    loadingMore: loadingMore ?? this.loadingMore,
    loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    mode: mode ?? this.mode,
    myCups: myCups ?? this.myCups,
    error: error,
  );

  @override
  List<Object?> get props => [
    status,
    stats,
    cards,
    total,
    hasMore,
    sort,
    ratingFilter,
    kind,
    loadingMore,
    loadMoreFailed,
    mode,
    myCups,
    error,
  ];
}

/// A cafe's cups (one per visit), a page at a time: the details section
/// loads one small page; the Cups page sorts, filters and pages on as it
/// scrolls.
class CafeCupsCubit extends Cubit<CafeCupsState> {
  CafeCupsCubit({
    required ICupsRepository repository,
    required this.cafeId,
    this.pageSize = sectionPageSize,
  }) : _repository = repository,
       super(const CafeCupsState());

  /// Two cards show on the details page; one more says whether there are
  /// others.
  static const sectionPageSize = 3;
  static const pagePageSize = 20;

  final ICupsRepository _repository;
  final String cafeId;
  final int pageSize;

  ICupsRepository get repository => _repository;

  int _epoch = 0;

  /// The first page. [refresh] keeps what is shown while it reloads.
  Future<void> load({bool refresh = false}) async {
    final epoch = ++_epoch;
    if (!refresh || state.status != CafeCupsStatus.loaded) {
      emit(
        CafeCupsState(
          status: CafeCupsStatus.loading,
          sort: state.sort,
          ratingFilter: state.ratingFilter,
          kind: state.kind,
          mode: state.mode,
        ),
      );
    }
    try {
      final page = await _repository.getCafeCups(
        cafeId,
        sort: state.sort,
        ratingFilter: state.ratingFilter,
        kind: state.kind,
        limit: pageSize,
      );
      if (isClosed || epoch != _epoch) return;
      emit(
        CafeCupsState(
          status: CafeCupsStatus.loaded,
          stats: page.stats,
          cards: List.unmodifiable(page.cards),
          total: page.total,
          hasMore: page.hasMore,
          sort: state.sort,
          ratingFilter: state.ratingFilter,
          kind: state.kind,
          mode: _repository.mode,
          myCups: List.unmodifiable(page.myCups),
        ),
      );
    } catch (e) {
      debugPrint('[CafeCups] load failed cafeId=$cafeId error=$e');
      if (isClosed || epoch != _epoch) return;
      if (refresh && state.status == CafeCupsStatus.loaded) {
        // A next page cut off by this refresh would leave paging stuck.
        if (state.loadingMore) emit(state.copyWith(loadingMore: false));
        return;
      }
      emit(
        CafeCupsState(
          status: CafeCupsStatus.failed,
          sort: state.sort,
          ratingFilter: state.ratingFilter,
          kind: state.kind,
          mode: _repository.mode,
          error: e,
        ),
      );
    }
  }

  /// The next page. After a failure only [retry] (the footer's Try again)
  /// asks again, so scrolling doesn't fire a request per scroll event.
  Future<void> loadMore({bool retry = false}) async {
    final current = state;
    if (!current.isLoaded || !current.hasMore || current.loadingMore) return;
    if (current.loadMoreFailed && !retry) return;
    final epoch = _epoch;
    emit(current.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await _repository.getCafeCups(
        cafeId,
        sort: current.sort,
        ratingFilter: current.ratingFilter,
        kind: current.kind,
        limit: pageSize,
        offset: current.cards.length,
      );
      if (isClosed || epoch != _epoch) return;
      final seen = {for (final c in current.cards) c.id};
      emit(
        state.copyWith(
          cards: List.unmodifiable([
            ...current.cards,
            ...page.cards.where((c) => !seen.contains(c.id)),
          ]),
          total: page.total,
          hasMore: page.hasMore,
          loadingMore: false,
        ),
      );
    } catch (e) {
      if (isClosed || epoch != _epoch) return;
      emit(state.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }

  void setSort(CupSort sort) {
    if (sort == state.sort) return;
    emit(state.copyWith(sort: sort));
    load();
  }

  /// Toggles the star filter: tapping the active one clears it.
  void setRatingFilter(int? stars) {
    if (stars == null || stars == state.ratingFilter) {
      if (state.ratingFilter == null) return;
      emit(state.copyWith(clearFilter: true));
    } else {
      emit(state.copyWith(ratingFilter: stars));
    }
    load();
  }

  /// Shows only cups with an item of [kind]; null (or the active one)
  /// shows all.
  void setKind(CupItemKind? kind) {
    if (kind == null || kind == state.kind) {
      if (state.kind == null) return;
      emit(state.copyWith(clearKind: true));
    } else {
      emit(state.copyWith(kind: kind));
    }
    load();
  }

  /// Cards with a Helpful toggle on its way.
  final _toggling = <String>{};

  /// Helpful on [card], shown at once and put back if it fails. Throws so
  /// the caller can say why. A tap while one is on its way is ignored, so a
  /// double tap can't send two toggles that land out of order. False when
  /// ignored.
  Future<bool> toggleHelpful(CupCard card) async {
    if (!_toggling.add(card.id)) return false;
    try {
      await _toggleHelpful(card);
      return true;
    } finally {
      _toggling.remove(card.id);
    }
  }

  Future<void> _toggleHelpful(CupCard card) async {
    final optimistic = card.copyWith(
      hasVoted: !card.hasVoted,
      helpfulCount: (card.helpfulCount + (card.hasVoted ? -1 : 1)).clamp(
        0,
        1 << 31,
      ),
    );
    _replace(card.id, optimistic);
    try {
      final now = await _repository.toggleHelpful(card);
      _replace(card.id, now);
    } catch (e) {
      _replace(card.id, card);
      rethrow;
    }
  }

  void _replace(String id, CupCard card) {
    if (isClosed) return;
    emit(
      state.copyWith(
        cards: List.unmodifiable([
          for (final c in state.cards) c.id == id ? card : c,
        ]),
      ),
    );
  }
}
