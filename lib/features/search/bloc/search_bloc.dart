import 'dart:async';
import 'package:nook/core/cafe/cafe_data_revision.dart';
import 'package:nook/core/utils/geo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/cafe_open_status.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/search/data/search_location.dart';
import 'package:nook/features/search/data/search_origin_store.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/use_cases/search_cafes_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stream_transform/stream_transform.dart';

part 'search_event.dart';
part 'search_state.dart';

const _debounceDuration = Duration(milliseconds: 400);

EventTransformer<E> debounce<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchCafesUseCase searchCafesUseCase;
  final SupabaseClient supabase;

  /// The place shared with the map; null keeps the origin to this search.
  final SearchOriginStore? originStore;

  final SearchLocationResolver _resolveLocation;

  SearchBloc({
    required this.searchCafesUseCase,
    required this.supabase,
    this.originStore,
    SearchLocationResolver? resolveLocation,
  }) : _resolveLocation = resolveLocation ?? resolveSearchLocation,
       super(SearchState(origin: originStore?.value)) {
    on<SearchQueryChanged>(
      _onQueryChanged,
      transformer: debounce(_debounceDuration),
    );
    on<SearchTagsChanged>(_onTagsChanged);
    on<SearchSortChanged>(_onSortChanged);
    on<SearchLoadMore>(_onLoadMore);
    on<SearchRefresh>(_onRefresh);
    on<SearchDismissLocationBanner>(_onDismissLocationBanner);
    on<SearchOriginChanged>(_onOriginChanged);
    on<SearchOpenNowToggled>(_onOpenNowToggled);
    on<SearchFiltersCleared>(_onFiltersCleared);
    on<SearchLocationChecked>(_onLocationChecked);
    CafeDataRevision.reviews.addListener(_onReviewsChanged);
  }

  /// A review was posted or deleted: rows on screen carry the old rating
  /// and count, so fetch them again (UX S6).
  void _onReviewsChanged() {
    if (isClosed || state.status != SearchStatus.success) return;
    add(const SearchRefresh());
  }

  @override
  Future<void> close() {
    CafeDataRevision.reviews.removeListener(_onReviewsChanged);
    return super.close();
  }

  /// Rows fetched to count a draft filter. A result this long may have been
  /// cut off, so it is not reported as a count. `get_cafes` rejects a limit
  /// above 100.
  static const countLimit = 100;

  /// How many cafes the results would hold with [tags] in place of the
  /// current ones: the number "Show N cafes" promises.
  ///
  /// There is no count RPC, so this runs the search itself with a larger
  /// page and counts the rows ("Open now" is applied on the device, as it
  /// is for the results). Null when the count would not be exact, or when
  /// there would be nothing to search.
  Future<int?> countFor(Set<String> tags) async {
    if (state.query.trim().isEmpty && tags.isEmpty) return null;
    final query = await _buildQuery(tags: tags, page: 0, limit: countLimit);
    final cafes = await searchCafesUseCase.call(query.query);
    if (cafes.length >= countLimit) return null;
    if (!state.openNow) return cafes.length;
    return cafes
        .where((c) => CafeOpenStatus.resolve(c.operatingHours).isOpen)
        .length;
  }

  Future<void> _onLocationChecked(
    SearchLocationChecked event,
    Emitter<SearchState> emit,
  ) async {
    final location = await _resolveLocation();
    if (location.status == state.location) return;
    emit(state.copyWith(location: location.status));
    // Results fetched without a position are stale once there is one (and
    // the other way round).
    if (state.origin == null &&
        _hasSomethingToSearch &&
        state.status != SearchStatus.loading) {
      emit(state.copyWith(status: SearchStatus.loading, cafes: [], page: 0));
      await _fetchCafes(emit);
    }
  }

  /// Rows fetched per search. The old 5-row first page assumed an idle list;
  /// the idle screen no longer shows results at all.
  static const _limit = 20;

  Future<void> _onOriginChanged(
    SearchOriginChanged event,
    Emitter<SearchState> emit,
  ) async {
    originStore?.set(event.origin);
    emit(
      state.copyWith(
        origin: event.origin,
        clearOrigin: event.origin == null,
        status: SearchStatus.loading,
        cafes: [],
        page: 0,
        clearLastError: true,
      ),
    );
    if (!_hasSomethingToSearch) {
      emit(state.copyWith(status: SearchStatus.initial));
      return;
    }
    await _fetchCafes(emit);
  }

  /// Filtered on the device, so no refetch.
  void _onOpenNowToggled(
    SearchOpenNowToggled event,
    Emitter<SearchState> emit,
  ) {
    emit(state.copyWith(openNow: !state.openNow));
  }

  Future<void> _onFiltersCleared(
    SearchFiltersCleared event,
    Emitter<SearchState> emit,
  ) async {
    emit(
      state.copyWith(
        tags: const {},
        openNow: false,
        sort: 'nearby',
        status: SearchStatus.loading,
        cafes: [],
        page: 0,
        clearLastError: true,
      ),
    );
    if (!_hasSomethingToSearch) {
      emit(state.copyWith(status: SearchStatus.initial));
      return;
    }
    await _fetchCafes(emit);
  }

  bool get _hasSomethingToSearch =>
      state.query.trim().isNotEmpty || state.tags.isNotEmpty;

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    // The same query again is only worth running when there is nothing to
    // show for it: not yet searched, or the last attempt failed.
    if (event.query == state.query &&
        state.status != SearchStatus.initial &&
        state.status != SearchStatus.failure) {
      return;
    }

    emit(
      state.copyWith(
        query: event.query,
        status: SearchStatus.loading,
        page: 0,
        hasReachedMax: false,
        cafes: [],
        clearLastError: true,
      ),
    );

    if (!_hasSomethingToSearch) {
      emit(state.copyWith(status: SearchStatus.initial));
      return;
    }
    await _fetchCafes(emit);
  }

  Future<void> _onTagsChanged(
    SearchTagsChanged event,
    Emitter<SearchState> emit,
  ) async {
    emit(
      state.copyWith(
        tags: event.tags,
        status: SearchStatus.loading,
        page: 0,
        hasReachedMax: false,
        cafes: [],
        clearLastError: true,
      ),
    );

    await _fetchCafes(emit);
  }

  Future<void> _onSortChanged(
    SearchSortChanged event,
    Emitter<SearchState> emit,
  ) async {
    emit(
      state.copyWith(
        sort: event.sort,
        status: SearchStatus.loading,
        page: 0,
        hasReachedMax: false,
        cafes: [],
        clearLastError: true,
      ),
    );

    await _fetchCafes(emit);
  }

  Future<void> _onLoadMore(
    SearchLoadMore event,
    Emitter<SearchState> emit,
  ) async {
    if (_loadingMore ||
        state.hasReachedMax ||
        state.status != SearchStatus.success) {
      return;
    }
    if (state.loadMoreFailed) {
      if (!event.retry) return;
      emit(state.copyWith(loadMoreFailed: false));
    }
    _loadingMore = true;
    try {
      await _fetchCafes(emit, page: state.page + 1);
    } finally {
      _loadingMore = false;
    }
  }

  /// The list asks for the next page from every build near its end.
  bool _loadingMore = false;

  Future<void> _onRefresh(
    SearchRefresh event,
    Emitter<SearchState> emit,
  ) async {
    emit(
      state.copyWith(
        status: SearchStatus.loading,
        page: 0,
        hasReachedMax: false,
        clearLastError: true,
      ),
    );

    await _fetchCafes(emit);
  }

  void _onDismissLocationBanner(
    SearchDismissLocationBanner event,
    Emitter<SearchState> emit,
  ) {
    emit(state.copyWith(locationBannerDismissed: true));
  }

  /// The `get_cafes` call for the current state, measured from the chosen
  /// place or else the phone. "Nearest" without a position becomes "Top
  /// rated": there is nothing to be near.
  Future<
    ({
      CafeQuery query,
      bool hasPosition,
      bool sortFellBack,
      SearchLocationStatus location,
    })
  >
  _buildQuery({
    Set<String>? tags,
    required int page,
    required int limit,
  }) async {
    final origin = state.origin;
    final SearchLocation phone = origin == null
        ? await _resolveLocation()
        : (lat: null, lng: null, status: state.location);
    final lat = origin?.lat ?? phone.lat;
    final lng = origin?.lng ?? phone.lng;
    final fellBack = state.sort == 'nearby' && lat == null;
    return (
      query: CafeQuery(
        query: state.query.trim().isEmpty ? null : state.query.trim(),
        tags: (tags ?? state.tags).toList(),
        sort: fellBack ? 'top_rated' : state.sort,
        lat: lat,
        lng: lng,
        userId: supabase.auth.currentUser?.id,
        page: page,
        limit: limit,
      ),
      hasPosition: lat != null,
      sortFellBack: fellBack,
      location: phone.status,
    );
  }

  /// get_cafes returns a distance only for the Nearest sort; with Top rated
  /// (or any other sort) the rows lost their km even with a place chosen.
  /// Fill in what the server left out, from the same point the query was
  /// measured from. (UX S8)
  static List<CafeSummary> withDistances(
    List<CafeSummary> cafes,
    double? lat,
    double? lng,
  ) {
    if (lat == null || lng == null) return cafes;
    final from = GeoPoint(lat: lat, lng: lng);
    return [
      for (final c in cafes)
        c.distanceMeters == null && c.lat != null && c.lng != null
            ? c.withDistance(
                haversineMeters(from, GeoPoint(lat: c.lat!, lng: c.lng!)),
              )
            : c,
    ];
  }

  /// Counts fetches. Only the query is debounced and switch-mapped; tags,
  /// sort, place, refresh and load-more overlap freely, so a response is
  /// applied only while its fetch is still the latest one.
  int _fetchSeq = 0;

  Future<void> _fetchCafes(Emitter<SearchState> emit, {int? page}) async {
    final request = ++_fetchSeq;
    final currentPage = page ?? state.page;
    try {
      const limit = _limit;
      final built = await _buildQuery(page: currentPage, limit: limit);

      final cafes = withDistances(
        await searchCafesUseCase.call(built.query),
        built.query.lat,
        built.query.lng,
      );
      if (request != _fetchSeq) return;

      emit(
        state.copyWith(
          status: SearchStatus.success,
          cafes: currentPage == 0
              ? cafes
              : (List.of(state.cafes)..addAll(cafes)),
          page: currentPage,
          hasReachedMax: cafes.length < limit,
          loadMoreFailed: false,
          clearLastError: true,
          locationDenied:
              built.sortFellBack && built.location == SearchLocationStatus.off,
          locationBannerDismissed: currentPage == 0
              ? false
              : state.locationBannerDismissed,
          hasPosition: built.hasPosition,
          sortFellBack: built.sortFellBack,
          location: built.location,
        ),
      );
    } catch (e, st) {
      debugPrint('SearchBloc: fetch cafes failed $e');
      debugPrint(st.toString());
      if (request != _fetchSeq) return;
      if (currentPage > 0) {
        // A later page failed: the results already on screen are still good.
        emit(state.copyWith(loadMoreFailed: true, lastError: e));
        return;
      }
      emit(
        state.copyWith(
          status: SearchStatus.failure,
          lastError: e,
          locationDenied: false,
          loadMoreFailed: false,
        ),
      );
    }
  }
}
