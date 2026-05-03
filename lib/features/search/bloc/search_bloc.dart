import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
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

  SearchBloc({
    required this.searchCafesUseCase,
    required this.supabase,
  }) : super(const SearchState()) {
    on<SearchQueryChanged>(_onQueryChanged, transformer: debounce(_debounceDuration));
    on<SearchTagsChanged>(_onTagsChanged);
    on<SearchSortChanged>(_onSortChanged);
    on<SearchLoadMore>(_onLoadMore);
    on<SearchRefresh>(_onRefresh);
  }

  Future<void> _onQueryChanged(SearchQueryChanged event, Emitter<SearchState> emit) async {
    if (event.query == state.query && state.status != SearchStatus.initial) return;
    
    emit(state.copyWith(
      query: event.query,
      status: SearchStatus.loading,
      page: 0,
      hasReachedMax: false,
      cafes: [],
    ));
    
    await _fetchCafes(emit);
  }

  Future<void> _onTagsChanged(SearchTagsChanged event, Emitter<SearchState> emit) async {
    emit(state.copyWith(
      tags: event.tags,
      status: SearchStatus.loading,
      page: 0,
      hasReachedMax: false,
      cafes: [],
    ));
    
    await _fetchCafes(emit);
  }

  Future<void> _onSortChanged(SearchSortChanged event, Emitter<SearchState> emit) async {
    emit(state.copyWith(
      sort: event.sort,
      status: SearchStatus.loading,
      page: 0,
      hasReachedMax: false,
      cafes: [],
    ));
    
    await _fetchCafes(emit);
  }

  Future<void> _onLoadMore(SearchLoadMore event, Emitter<SearchState> emit) async {
    return;
  }

  Future<void> _onRefresh(SearchRefresh event, Emitter<SearchState> emit) async {
    emit(state.copyWith(
      status: SearchStatus.loading,
      page: 0,
      hasReachedMax: false,
    ));
    
    await _fetchCafes(emit);
  }

  Future<void> _fetchCafes(Emitter<SearchState> emit, {int? page}) async {
    try {
      final currentPage = page ?? state.page;
      final location = await _resolveLocation();
      final userId = supabase.auth.currentUser?.id;
      final isInitialLoad = currentPage == 0 && state.query.trim().isEmpty;
      final limit = isInitialLoad ? 5 : 20;

      final resolvedSort =
          (state.sort == 'nearby' && location == null) ? 'top_rated' : state.sort;

      final query = CafeQuery(
        query: state.query.trim().isEmpty ? null : state.query.trim(),
        tags: state.tags.toList(),
        sort: resolvedSort,
        lat: location?.latitude,
        lng: location?.longitude,
        userId: userId,
        page: currentPage,
        limit: limit,
      );

      debugPrint(
        'SearchBloc: fetch cafes query="${query.query}" tags=${query.tags.length} '
        'sort=${query.sort} page=${query.page} lat=${query.lat} lng=${query.lng} '
        'userId=${userId ?? 'null'}',
      );

      final cafes = await searchCafesUseCase.call(query);
      debugPrint('SearchBloc: fetch cafes success count=${cafes.length}');

      if (currentPage == 0) {
        emit(state.copyWith(
          status: SearchStatus.success,
          cafes: cafes,
          page: 0,
          hasReachedMax: cafes.length < limit,
        ));
      } else {
        emit(state.copyWith(
          status: SearchStatus.success,
          cafes: List.of(state.cafes)..addAll(cafes),
          page: currentPage,
          hasReachedMax: cafes.length < limit,
        ));
      }
    } catch (e, st) {
      debugPrint('SearchBloc: fetch cafes failed $e');
      debugPrint(st.toString());
      emit(state.copyWith(
        status: SearchStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<Position?> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 100,
        ),
      ).timeout(const Duration(seconds: 3), onTimeout: () => throw TimeoutException('Location timeout'));
    } catch (e, st) {
      debugPrint('SearchBloc: resolve location failed $e');
      debugPrint(st.toString());
      return null;
    }
  }
}
