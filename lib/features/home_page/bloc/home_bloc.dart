import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/home_page/domain/use_cases/get_cafe_summaries_usecase.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetHomeFeedUseCase getHomeFeedUseCase;

  HomeBloc({required this.getHomeFeedUseCase}) : super(HomeInitialState()) {
    on<LoadHomeDataEvent>(_onLoadHomeData);
    on<HomeDismissLocationBannerEvent>(_onDismissLocationBanner);
  }

  Future<void> _onLoadHomeData(
    LoadHomeDataEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoadingState());

    try {
      final out = await getHomeFeedUseCase.call();

      final featured = _buildFeatured(out.feed);
      final allEmpty =
          featured.isEmpty &&
          out.feed.newest.isEmpty &&
          out.feed.trending.isEmpty &&
          out.feed.topRated.isEmpty;

      emit(
        HomeLoadedState(
          featuredCafes: featured,
          newestCafes: out.feed.newest,
          trendingCafes: out.feed.trending,
          topRatedCafes: out.feed.topRated,
          locationDenied: out.locationDenied,
          locationBannerDismissed: false,
          allEmpty: allEmpty,
        ),
      );
    } catch (e) {
      emit(HomeError(e));
    }
  }

  void _onDismissLocationBanner(
    HomeDismissLocationBannerEvent event,
    Emitter<HomeState> emit,
  ) {
    final s = state;
    if (s is HomeLoadedState) {
      emit(s.copyWith(locationBannerDismissed: true));
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
