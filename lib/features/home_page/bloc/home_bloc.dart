import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/home_page/domain/use_cases/get_cafe_summaries_usecase.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';

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

      emit(
        HomeLoadedState(
          featuredCafes: _buildFeatured(result),
          newestCafes: result.newest,
          trendingCafes: result.trending,
          topRatedCafes: result.topRated,
        ),
      );
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  List<CafeSummary> _buildFeatured(HomeFeedResult result) {
    final seenIds = <String>{};
    return [
          ...result.newest,
          ...result.trending,
          ...result.topRated,
          ...result.nearby,
        ]
        .where((summary) => summary.isFeatured)
        .where((summary) => seenIds.add(summary.id))
        .toList();
  }
}
