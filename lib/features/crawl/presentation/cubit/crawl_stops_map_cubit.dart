import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stop.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_stops_map_state.dart';
import 'package:nook/features/map/domain/use_cases/get_cafe_cards_usecase.dart';

class CrawlStopsMapCubit extends Cubit<CrawlStopsMapState> {
  final GetCafeCardUseCase getCafeCardUseCase;

  CrawlStopsMapCubit(this.getCafeCardUseCase) : super(CrawlStopsMapInitial());

  Future<void> loadCafes(List<CrawlStop> stops) async {
    emit(CrawlStopsMapLoading());
    try {
      final result = await getCafeCardUseCase.call(limit: 50);
      final stopCafeIds = stops.map((s) => s.cafeId).toSet();
      final filtered = result.cafes
          .where((c) => stopCafeIds.contains(c.id))
          .toList();
      final cafeById = {for (final c in filtered) c.id: c};
      emit(CrawlStopsMapLoaded(cafeById: cafeById, cafes: filtered));
    } catch (e) {
      emit(CrawlStopsMapError(e));
    }
  }
}
