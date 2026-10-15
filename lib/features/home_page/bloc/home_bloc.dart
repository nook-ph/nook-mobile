import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/cafe_data_revision.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:nook/features/home_page/data/home_layout_repository.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';
import 'package:nook/features/home_page/domain/use_cases/get_cafe_summaries_usecase.dart';
import 'package:nook/features/home_page/domain/use_cases/get_layout_shelves_usecase.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';

/// Reviews a cafe needs before a rating-based shelf counts it. One 5-star
/// review is not a ranking (docs: COFFEE_VOICE.md, accuracy rules).
const minShelfReviews = 3;

/// "Crowd favorites" (the `trending` sort: rating weighted by review volume).
/// Only cafes with enough reviews, and the shelf stays hidden until at least
/// five qualify; below that it only repeats House picks.
List<CafeSummary> crowdFavorites(List<CafeSummary> cafes) {
  final rated = cafes.where((c) => c.reviewCount >= minShelfReviews).toList();
  return rated.length >= 5 ? rated : const [];
}

/// "Highest rated": only cafes with enough reviews, hidden if fewer than
/// three are left.
List<CafeSummary> highestRated(List<CafeSummary> cafes) {
  final rated = cafes.where((c) => c.reviewCount >= minShelfReviews).toList();
  return rated.length >= 3 ? rated : const [];
}

/// Cafes "Local beans" needs before it shows (docs COFFEE_TAGS.md §5). The
/// tag is new and owner-set, so a shelf of one or two would read as broken.
const minLocalBeans = 3;

/// "Local beans": the Philippine Beans cafes, or nothing below
/// [minLocalBeans].
List<CafeSummary> localBeans(List<CafeSummary> cafes) =>
    cafes.length >= minLocalBeans ? cafes : const [];

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetHomeFeedUseCase getHomeFeedUseCase;

  /// Reads the onboarding purpose, whose shelf leads the feed.
  final Future<OnboardingPurpose?> Function()? readPurpose;

  /// The admin-controlled layout. Null keeps the built-in Home.
  final HomeLayoutRepository? layoutRepository;

  /// Loads the cafes a layout adds (House picks, custom shelves).
  final GetLayoutShelvesUseCase? getLayoutShelves;

  /// Debug builds only: a layout built from the loaded feed (so it can use
  /// real cafe ids), used instead of the server's. Never set in release.
  final HomeLayout Function(HomeFeedResult feed)? debugLayoutFixture;

  HomeBloc({
    required this.getHomeFeedUseCase,
    this.readPurpose,
    this.layoutRepository,
    this.getLayoutShelves,
    this.debugLayoutFixture,
  }) : super(HomeInitialState()) {
    on<LoadHomeDataEvent>(_onLoadHomeData);
    on<HomeDismissLocationBannerEvent>(_onDismissLocationBanner);
    CafeDataRevision.reviews.addListener(_onReviewsChanged);
  }

  /// A review was posted or deleted: the shelves' ratings and counts are
  /// stale, so refresh in place (UX S6).
  void _onReviewsChanged() {
    if (isClosed || state is! HomeLoadedState) return;
    add(LoadHomeDataEvent(refresh: true));
  }

  @override
  Future<void> close() {
    CafeDataRevision.reviews.removeListener(_onReviewsChanged);
    return super.close();
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

    final purpose = await _readPurpose();

    // The layout loads alongside the feed: the cached one (and its shelves)
    // for this paint, the server's behind it.
    final layoutRepository = this.layoutRepository;
    final fixture = debugLayoutFixture;
    HomeLayout? layout;
    var layoutShelves = const <String, List<CafeSummary>>{};
    Future<void>? layoutReady;
    Future<HomeLayoutRefresh>? refreshed;
    if (fixture == null && layoutRepository != null) {
      final cachedLayout = layoutRepository.cached();
      // Asked after the cache is read, so "changed" compares with it.
      refreshed = cachedLayout.then((_) => layoutRepository.refresh());
      layoutReady = () async {
        layout = await cachedLayout;
        layoutShelves = await _shelvesFor(layout);
      }();
    }

    try {
      // Cafes already announced in this load, so the page asks for each
      // cafe's status once.
      var announced = <String>{};
      var firstStep = true;

      await for (final update in getHomeFeedUseCase.watch()) {
        if (emit.isDone) return;
        final out = update.data;

        if (fixture != null && layout == null) {
          layout = fixture(out.feed);
          layoutShelves = await _shelvesFor(layout);
        }
        await layoutReady;
        if (emit.isDone) return;

        // The early step of a refresh has no "Near you" yet. The one on
        // screen stays until its replacement arrives.
        final current = state;
        final nearby =
            update.nearbyPending && event.refresh && current is HomeLoadedState
            ? current.nearbyCafes
            : out.feed.nearby;

        final featured = _buildFeatured(out.feed, nearby);
        final trending = crowdFavorites(out.feed.trending);
        final topRated = highestRated(out.feed.topRated);
        final specialty =
            update.nearbyPending && event.refresh && current is HomeLoadedState
            ? current.specialtyNearbyCafes
            : out.feed.specialtyNearby;
        // Local beans also waits on the position; same hand-over as above.
        final beans =
            update.nearbyPending && event.refresh && current is HomeLoadedState
            ? current.localBeansCafes
            : localBeans(out.feed.localBeans);
        final allEmpty =
            featured.isEmpty &&
            nearby.isEmpty &&
            out.feed.newest.isEmpty &&
            trending.isEmpty &&
            topRated.isEmpty &&
            specialty.isEmpty &&
            beans.isEmpty &&
            out.feed.laptopFriendly.isEmpty;

        final loaded = HomeLoadedState(
          featuredCafes: featured,
          nearbyCafes: nearby,
          newestCafes: out.feed.newest,
          trendingCafes: trending,
          topRatedCafes: topRated,
          specialtyNearbyCafes: specialty,
          laptopFriendlyCafes: out.feed.laptopFriendly,
          localBeansCafes: beans,
          locationDenied: out.locationDenied,
          locationServicesOff: out.locationServicesOff,
          // Dismissed between the two steps of one load: stays dismissed.
          locationBannerDismissed:
              !firstStep &&
              current is HomeLoadedState &&
              current.locationBannerDismissed,
          allEmpty: allEmpty,
          purpose: purpose,
          layout: layout,
          layoutShelves: layoutShelves,
        );
        emit(loaded.copyWith(newCafeIds: loaded.cafeIds.difference(announced)));
        announced = loaded.cafeIds;
        firstStep = false;
      }

      // The server's layout, once the feed is on screen. Only a change is
      // drawn; a failed fetch keeps the cached layout (or the built-in Home).
      final fresh = await refreshed;
      final current = state;
      if (fresh != null &&
          fresh.changed &&
          !emit.isDone &&
          current is HomeLoadedState) {
        final shelves = await _shelvesFor(fresh.layout);
        if (emit.isDone) return;
        final next = fresh.layout == null
            ? current.copyWith(clearLayout: true)
            : current.copyWith(layout: fresh.layout, layoutShelves: shelves);
        emit(next.copyWith(newCafeIds: next.cafeIds.difference(announced)));
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

  Future<Map<String, List<CafeSummary>>> _shelvesFor(HomeLayout? layout) async {
    final load = getLayoutShelves;
    if (layout == null || load == null) return const {};
    try {
      return await load(layout);
    } catch (_) {
      return const {};
    }
  }

  Future<OnboardingPurpose?> _readPurpose() async {
    try {
      return await readPurpose?.call();
    } catch (_) {
      return null;
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
