import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/usecases/get_cafe_summaries_usecase.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetHomeFeedUseCase getHomeFeedUseCase;

  HomeBloc({required this.getHomeFeedUseCase}) : super(HomeInitialState()) {
    on<LoadHomeDataEvent>(_onLoadHomeData);
  }

  Future<void> _onLoadHomeData(
    LoadHomeDataEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoadingState());

    try {
      final result = await getHomeFeedUseCase.call();

      final newest = result.newest.map(_toFeatureSummary).toList();
      final trending = result.trending.map(_toFeatureSummary).toList();
      final topRated = result.topRated.map(_toFeatureSummary).toList();
      final featured = _buildFeatured(result);

      emit(
        HomeLoadedState(
          featuredCafes: featured,
          newestCafes: newest,
          trendingCafes: trending,
          topRatedCafes: topRated,
        ),
      );
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  List<CafeSummaryEntity> _buildFeatured(HomeFeedResult result) {
    final seenIds = <String>{};
    final all = [
      ...result.newest,
      ...result.trending,
      ...result.topRated,
      ...result.nearby,
    ];

    return all
        .where((summary) => summary.isFeatured)
        .where((summary) => seenIds.add(summary.id))
        .map(_toFeatureSummary)
        .toList();
  }

  CafeSummaryEntity _toFeatureSummary(CafeSummary summary) {
    return CafeSummaryEntity(
      id: summary.id,
      name: summary.name,
      address: summary.address,
      rating: summary.rating,
      featuredImageUrl: summary.coverImage,
      isFeatured: summary.isFeatured,
      tags: summary.tags,
    );
  }
}
