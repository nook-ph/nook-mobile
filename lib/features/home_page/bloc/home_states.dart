import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

abstract class HomeState {}

class HomeInitialState extends HomeState {}

class HomeLoadingState extends HomeState {}

class HomeLoadedState extends HomeState {
  final List<CafeSummary> featuredCafes;

  /// Cafes closest to the device. Empty without a position.
  final List<CafeSummary> nearbyCafes;
  final List<CafeSummary> newestCafes;
  final List<CafeSummary> trendingCafes;
  final List<CafeSummary> topRatedCafes;

  /// Permission denied for device location (nearby/boost data may be limited).
  final bool locationDenied;

  /// The phone's Location Services switch is off.
  final bool locationServicesOff;

  /// User dismissed the location banner for this loaded session.
  final bool locationBannerDismissed;

  /// True when all sections (featured, nearby, newest, trending, topRated)
  /// came back empty. Used by the UI to distinguish "no cafes in DB" from
  /// "everything failed silently".
  final bool allEmpty;

  /// The cafes this emission added to the feed. A load can emit twice (the
  /// sections that need no position, then "Near you"), and the status lookup
  /// should only ask about each cafe once. Null means all of [cafeIds].
  final Set<String>? newCafeIds;

  HomeLoadedState({
    required this.featuredCafes,
    this.nearbyCafes = const [],
    required this.newestCafes,
    required this.trendingCafes,
    required this.topRatedCafes,
    this.locationDenied = false,
    this.locationServicesOff = false,
    this.locationBannerDismissed = false,
    this.allEmpty = false,
    this.newCafeIds,
  });

  /// Every cafe on the feed, for the one batched status lookup.
  Set<String> get cafeIds => {
    for (final cafe in featuredCafes) cafe.id,
    for (final cafe in nearbyCafes) cafe.id,
    for (final cafe in newestCafes) cafe.id,
    for (final cafe in trendingCafes) cafe.id,
    for (final cafe in topRatedCafes) cafe.id,
  };

  bool get hasCafes => cafeIds.isNotEmpty;

  /// Which location notice applies, if it has not been dismissed.
  bool get showLocationBanner =>
      (locationDenied || locationServicesOff) && !locationBannerDismissed;

  HomeLoadedState copyWith({
    List<CafeSummary>? featuredCafes,
    List<CafeSummary>? nearbyCafes,
    List<CafeSummary>? newestCafes,
    List<CafeSummary>? trendingCafes,
    List<CafeSummary>? topRatedCafes,
    bool? locationDenied,
    bool? locationServicesOff,
    bool? locationBannerDismissed,
    bool? allEmpty,
    Set<String>? newCafeIds,
  }) {
    return HomeLoadedState(
      featuredCafes: featuredCafes ?? this.featuredCafes,
      nearbyCafes: nearbyCafes ?? this.nearbyCafes,
      newestCafes: newestCafes ?? this.newestCafes,
      trendingCafes: trendingCafes ?? this.trendingCafes,
      topRatedCafes: topRatedCafes ?? this.topRatedCafes,
      locationDenied: locationDenied ?? this.locationDenied,
      locationServicesOff: locationServicesOff ?? this.locationServicesOff,
      locationBannerDismissed:
          locationBannerDismissed ?? this.locationBannerDismissed,
      allEmpty: allEmpty ?? this.allEmpty,
      newCafeIds: newCafeIds ?? this.newCafeIds,
    );
  }
}

class HomeError extends HomeState {
  final Object error;

  HomeError(this.error);
}
