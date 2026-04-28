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
  }

  Future<void> _onLoadMapData(
    LoadMapDataEvent event,
    Emitter<MapState> emit,
  ) async {
    emit(MapLoadingState());
    try {
      final result = await getCafeCardUseCase.call(tags: event.tags);
      final currentTags = state is MapLoadedState
          ? (state as MapLoadedState).tags
          : <CafeTagsEntity>[];
      emit(MapLoadedState(cafes: result.cafes, tags: currentTags));
    } catch (e) {
      emit(MapError(e.toString()));
    }
  }

  Future<void> _onLoadFilterTags(
    LoadFilterTagsEvent event,
    Emitter<MapState> emit,
  ) async {
    try {
      final tags = await getFilterTagsUseCase.call();
      final currentCafes = state is MapLoadedState
          ? (state as MapLoadedState).cafes
          : <CafeSummary>[];
      emit(MapLoadedState(cafes: currentCafes, tags: tags));
    } catch (e) {
      emit(MapError(e.toString()));
    }
  }
}
