import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

abstract class HomeState {}

class HomeInitialState extends HomeState {}

class HomeLoadingState extends HomeState {}

class HomeLoadedState extends HomeState {
  final List<CafeSummary> featuredCafes;
  final List<CafeSummary> newestCafes;
  final List<CafeSummary> trendingCafes;
  final List<CafeSummary> topRatedCafes;

  /// Permission denied for device location (nearby/boost data may be limited).
  final bool locationDenied;

  /// User dismissed the location banner for this loaded session.
  final bool locationBannerDismissed;

  /// True when all sections (featured, newest, trending, topRated) came back
  /// empty. Used by the UI to distinguish "no cafes in DB" from
  /// "everything failed silently".
  final bool allEmpty;

  HomeLoadedState({
    required this.featuredCafes,
    required this.newestCafes,
    required this.trendingCafes,
    required this.topRatedCafes,
    this.locationDenied = false,
    this.locationBannerDismissed = false,
    this.allEmpty = false,
  });

  HomeLoadedState copyWith({
    List<CafeSummary>? featuredCafes,
    List<CafeSummary>? newestCafes,
    List<CafeSummary>? trendingCafes,
    List<CafeSummary>? topRatedCafes,
    bool? locationDenied,
    bool? locationBannerDismissed,
    bool? allEmpty,
  }) {
    return HomeLoadedState(
      featuredCafes: featuredCafes ?? this.featuredCafes,
      newestCafes: newestCafes ?? this.newestCafes,
      trendingCafes: trendingCafes ?? this.trendingCafes,
      topRatedCafes: topRatedCafes ?? this.topRatedCafes,
      locationDenied: locationDenied ?? this.locationDenied,
      locationBannerDismissed:
          locationBannerDismissed ?? this.locationBannerDismissed,
      allEmpty: allEmpty ?? this.allEmpty,
    );
  }
}

class HomeError extends HomeState {
  final Object error;

  HomeError(this.error);
}
