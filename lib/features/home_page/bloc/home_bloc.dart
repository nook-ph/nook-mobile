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
    // A refresh keeps the loaded feed on screen; anything else shows the
    // skeleton.
    if (!(event.refresh && state is HomeLoadedState)) {
      emit(HomeLoadingState());
    }

    try {
      // Cafes already announced in this load, so the page asks for each
      // cafe's status once.
      var announced = <String>{};
      var firstStep = true;

      await for (final update in getHomeFeedUseCase.watch()) {
        if (emit.isDone) return;
        final out = update.data;

        // The early step of a refresh has no "Near you" yet. The one on
        // screen stays until its replacement arrives.
        final current = state;
        final nearby =
            update.nearbyPending && event.refresh && current is HomeLoadedState
            ? current.nearbyCafes
            : out.feed.nearby;

        final featured = _buildFeatured(out.feed, nearby);
        final allEmpty =
            featured.isEmpty &&
            nearby.isEmpty &&
            out.feed.newest.isEmpty &&
            out.feed.trending.isEmpty &&
            out.feed.topRated.isEmpty;

        final loaded = HomeLoadedState(
          featuredCafes: featured,
          nearbyCafes: nearby,
          newestCafes: out.feed.newest,
          trendingCafes: out.feed.trending,
          topRatedCafes: out.feed.topRated,
          locationDenied: out.locationDenied,
          locationServicesOff: out.locationServicesOff,
          // Dismissed between the two steps of one load: stays dismissed.
          locationBannerDismissed:
              !firstStep &&
              current is HomeLoadedState &&
              current.locationBannerDismissed,
          allEmpty: allEmpty,
        );
        emit(loaded.copyWith(newCafeIds: loaded.cafeIds.difference(announced)));
        announced = loaded.cafeIds;
        firstStep = false;
      }
    } catch (e) {
      // A refresh that fails keeps the feed it was refreshing; only the
      // failure is reported.
      final current = state;
      if (event.refresh && current is HomeLoadedState) {
        emit(current.copyWith(refreshError: e));
        return;
      }
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

  List<CafeSummary> _buildFeatured(
    HomeFeedResult result,
    List<CafeSummary> nearby,
  ) {
    final seenIds = <String>{};
    return [...result.newest, ...result.trending, ...result.topRated, ...nearby]
        .where((summary) => summary.isFeatured)
        .where((summary) => seenIds.add(summary.id))
        .toList();
  }
}
