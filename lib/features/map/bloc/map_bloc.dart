import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/core/utils/geo.dart';
import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';
import 'package:nook/features/map/domain/use_cases/get_cafe_cards_usecase.dart';
import 'package:nook/features/map/domain/use_cases/get_cafes_for_viewport_usecase.dart';
import 'package:nook/features/map/domain/use_cases/get_filter_tags_usecase.dart';
import 'package:nook/features/map/bloc/map_states.dart';
import 'package:nook/features/map/bloc/map_event.dart';
import 'package:stream_transform/stream_transform.dart';

/// Debounces bursts of events and cancels the in-flight handler when a newer
/// event arrives — the AbortController+setTimeout combo the webapp uses.
EventTransformer<E> _debounceRestartable<E>(Duration duration) {
  return (events, mapper) => events.debounce(duration).switchMap(mapper);
}

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc({
    required this.getCafeCardUseCase,
    required this.getFilterTagsUseCase,
    required this.getCafesForViewportUseCase,
  }) : super(MapInitialState()) {
    on<LoadMapDataEvent>(_onLoadMapData);
    on<MapViewportChangedEvent>(
      _onViewportChanged,
      transformer: _debounceRestartable(viewportDebounce),
    );
    on<LoadFilterTagsEvent>(_onLoadFilterTags);
    on<MapDismissLocationBannerEvent>(_onDismissLocationBanner);
  }

  final GetCafeCardUseCase getCafeCardUseCase;
  final GetFilterTagsUseCase getFilterTagsUseCase;
  final GetCafesForViewportUseCase getCafesForViewportUseCase;

  /// Tags fetched while still in [MapLoadingState]; applied when cafe load completes.
  List<CafeTagsEntity>? _pendingFilterTags;

  /// The filter the last fetch ran with; viewport refetches reuse it.
  CafeFilter _filter = const CafeFilter();

  /// The most recent viewport reported by the map, so applying filters can
  /// immediately re-fetch the area the user is currently looking at.
  MapViewport? _lastViewport;

  /// Monotonic fetch counter; responses that don't match the latest id are
  /// stale (a newer fetch started while they were in flight) and get dropped.
  int _fetchId = 0;

  static const viewportDebounce = Duration(milliseconds: 300);
  static const _mapLoadTimeout = Duration(seconds: 30);
  static const _filterTagsTimeout = Duration(seconds: 30);

  Future<void> _onLoadMapData(
    LoadMapDataEvent event,
    Emitter<MapState> emit,
  ) async {
    _filter = event.filter;

    // Once the map has a viewport, filter changes refetch what the user is
    // currently looking at instead of restarting the whole page.
    final viewport = _lastViewport;
    if (viewport != null && state is MapLoadedState) {
      await _fetchViewport(viewport, emit);
      return;
    }

    emit(MapLoadingState());
    final fetchId = ++_fetchId;
    try {
      final result = await getCafeCardUseCase
          .call(filter: event.filter)
          .timeout(
            _mapLoadTimeout,
            onTimeout: () => throw TimeoutException('Map load timed out'),
          );
      if (fetchId != _fetchId) return;

      final tags =
          _pendingFilterTags ??
          (state is MapLoadedState
              ? (state as MapLoadedState).tags
              : <CafeTagsEntity>[]);
      _pendingFilterTags = null;

      emit(
        MapLoadedState(
          cafes: result.cafes,
          tags: tags,
          locationDenied: result.locationDenied,
          locationBannerDismissed: false,
        ),
      );
    } catch (e) {
      if (fetchId != _fetchId) return;
      _pendingFilterTags = null;
      emit(MapError(e));
    }
  }

  Future<void> _onViewportChanged(
    MapViewportChangedEvent event,
    Emitter<MapState> emit,
  ) async {
    _lastViewport = event.viewport;
    // Viewport fetches only refresh an already-loaded map; the initial load
    // (and its error handling) belongs to LoadMapDataEvent.
    if (state is! MapLoadedState) return;
    await _fetchViewport(event.viewport, emit);
  }

  Future<void> _fetchViewport(
    MapViewport viewport,
    Emitter<MapState> emit,
  ) async {
    final loaded = state as MapLoadedState;
    final fetchId = ++_fetchId;
    emit(loaded.copyWith(isRefreshing: true));

    try {
      final cafes = await getCafesForViewportUseCase
          .call(viewport: viewport, filter: _filter)
          .timeout(
            _mapLoadTimeout,
            onTimeout: () => throw TimeoutException('Map refresh timed out'),
          );
      if (fetchId != _fetchId || emit.isDone) return;
      emit(loaded.copyWith(cafes: cafes, isRefreshing: false));
    } catch (_) {
      // Keep the previous list on refetch errors (webapp behavior); just
      // drop the loading chip.
      if (fetchId != _fetchId || emit.isDone) return;
      emit(loaded.copyWith(isRefreshing: false));
    }
  }

  Future<void> _onLoadFilterTags(
    LoadFilterTagsEvent event,
    Emitter<MapState> emit,
  ) async {
    try {
      final tags = await getFilterTagsUseCase.call().timeout(
        _filterTagsTimeout,
        onTimeout: () => throw TimeoutException('Filter tags timed out'),
      );
      final current = state;
      if (current is MapLoadedState) {
        emit(current.copyWith(tags: tags));
      } else if (current is MapLoadingState) {
        _pendingFilterTags = tags;
      } else {
        emit(MapLoadedState(cafes: const [], tags: tags));
      }
    } catch (e) {
      emit(MapError(e));
    }
  }

  void _onDismissLocationBanner(
    MapDismissLocationBannerEvent event,
    Emitter<MapState> emit,
  ) {
    final s = state;
    if (s is MapLoadedState) {
      emit(s.copyWith(locationBannerDismissed: true));
    }
  }
}
