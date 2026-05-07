import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';
import 'package:nook/features/map/domain/use_cases/get_cafe_cards_usecase.dart';
import 'package:nook/features/map/domain/use_cases/get_filter_tags_usecase.dart';
import 'package:nook/features/map/bloc/map_states.dart';
import 'package:nook/features/map/bloc/map_event.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  final GetCafeCardUseCase getCafeCardUseCase;
  final GetFilterTagsUseCase getFilterTagsUseCase;

  MapBloc({
    required this.getCafeCardUseCase,
    required this.getFilterTagsUseCase,
  }) : super(MapInitialState()) {
    on<LoadMapDataEvent>(_onLoadMapData);
    on<LoadFilterTagsEvent>(_onLoadFilterTags);
    on<MapDismissLocationBannerEvent>(_onDismissLocationBanner);
  }

  Future<void> _onLoadMapData(
    LoadMapDataEvent event,
    Emitter<MapState> emit,
  ) async {
    emit(MapLoadingState());
    try {
      final result = await getCafeCardUseCase.call(filter: event.filter);
      final currentTags = state is MapLoadedState
          ? (state as MapLoadedState).tags
          : <CafeTagsEntity>[];
      emit(
        MapLoadedState(
          cafes: result.cafes,
          tags: currentTags,
          locationDenied: result.locationDenied,
          locationBannerDismissed: false,
        ),
      );
    } catch (e) {
      emit(MapError(e));
    }
  }

  Future<void> _onLoadFilterTags(
    LoadFilterTagsEvent event,
    Emitter<MapState> emit,
  ) async {
    try {
      final tags = await getFilterTagsUseCase.call();
      final current = state;
      if (current is MapLoadedState) {
        emit(current.copyWith(tags: tags));
      } else {
        final currentCafes = current is MapLoadedState
            ? current.cafes
            : <CafeSummary>[];
        emit(MapLoadedState(cafes: currentCafes, tags: tags));
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
