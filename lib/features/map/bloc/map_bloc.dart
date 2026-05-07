import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';
import 'package:nook/features/map/domain/use_cases/get_cafe_cards_usecase.dart';
import 'package:nook/features/map/domain/use_cases/get_filter_tags_usecase.dart';
import 'package:nook/features/map/bloc/map_states.dart';
import 'package:nook/features/map/bloc/map_event.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc({
    required this.getCafeCardUseCase,
    required this.getFilterTagsUseCase,
  }) : super(MapInitialState()) {
    on<LoadMapDataEvent>(_onLoadMapData);
    on<LoadFilterTagsEvent>(_onLoadFilterTags);
    on<MapDismissLocationBannerEvent>(_onDismissLocationBanner);
  }

  final GetCafeCardUseCase getCafeCardUseCase;
  final GetFilterTagsUseCase getFilterTagsUseCase;

  /// Tags fetched while still in [MapLoadingState]; applied when cafe load completes.
  List<CafeTagsEntity>? _pendingFilterTags;

  static const _mapLoadTimeout = Duration(seconds: 30);
  static const _filterTagsTimeout = Duration(seconds: 30);

  Future<void> _onLoadMapData(
    LoadMapDataEvent event,
    Emitter<MapState> emit,
  ) async {
    emit(MapLoadingState());
    try {
      final result = await getCafeCardUseCase
          .call(filter: event.filter)
          .timeout(
            _mapLoadTimeout,
            onTimeout: () => throw TimeoutException('Map load timed out'),
          );

      final tags = _pendingFilterTags ??
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
      _pendingFilterTags = null;
      emit(MapError(e));
    }
  }

  Future<void> _onLoadFilterTags(
    LoadFilterTagsEvent event,
    Emitter<MapState> emit,
  ) async {
    try {
      final tags = await getFilterTagsUseCase
          .call()
          .timeout(
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
