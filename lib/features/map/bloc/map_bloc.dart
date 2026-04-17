import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/map/domain/use_cases/get_cafe_cards_usecase.dart';
import 'package:nook/features/map/bloc/map_states.dart';
import 'package:nook/features/map/bloc/map_event.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  final GetCafeCardUseCase getCafeCardUseCase;

  MapBloc({required this.getCafeCardUseCase}) : super(MapInitialState()) {
    on<LoadMapDataEvent>(_onLoadMapData);
  }

  Future<void> _onLoadMapData(
    LoadMapDataEvent event,
    Emitter<MapState> emit,
  ) async {
    emit(MapLoadingState());
    try {
      final result = await getCafeCardUseCase.call(
        tags: event.tags,
      );
      emit(MapLoadedState(cafes: result.cafes));
    } catch (e) {
      emit(MapError(e.toString()));
    }
  }
}
