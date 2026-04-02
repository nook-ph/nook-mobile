import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/usecases/get_cafe_summaries_usecase.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';
import 'package:flutter/foundation.dart';

class  HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetCafeSummariesUseCase getCafeSummariesUseCase;

  HomeBloc({required this.getCafeSummariesUseCase})
    : super(HomeInitialState()) {
    on<LoadHomeDataEvent>(_onLoadHomeData);
  }

  Future<void> _onLoadHomeData(
    LoadHomeDataEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoadingState());

    try {
      debugPrint('[HomeBloc] Fetching home cafes...');
      final result = await getCafeSummariesUseCase.call();

      final featured = result.featured.map(_toFeatureSummary).toList();
      final recommended = result.recommended.map(_toFeatureSummary).toList();

      debugPrint(
        '[HomeBloc] Fetch success featured=${featured.length} recommended=${recommended.length}',
      );

      emit(
        HomeLoadedState(featuredCafes: featured, recommendedCafes: recommended),
      );
    } catch (e) {
      debugPrint('[HomeBloc] Fetch error: $e');
      emit(HomeError(e.toString()));
    }
  }

  CafeSummaryEntity _toFeatureSummary(CafeSummary summary) {
    return CafeSummaryEntity(
      id: summary.id,
      name: summary.name,
      address: summary.address,
      rating: summary.rating,
      featuredImageUrl: summary.coverImage,
      systemBadge: summary.isFeatured ? 'featured' : null,
      tags: summary.tags,
    );
  }
}
