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

  /// Cafes tagged Specialty Coffee, closest first. Empty without a position.
  final List<CafeSummary> specialtyNearbyCafes;

  /// Cafes with both Free WiFi and Power Outlets.
  final List<CafeSummary> laptopFriendlyCafes;

  /// Permission denied for device location (nearby/boost data may be limited).
  final bool locationDenied;

  /// The phone's Location Services switch is off.
  final bool locationServicesOff;

  /// User dismissed the location banner for this loaded session.
  final bool locationBannerDismissed;

  /// True when every section came back empty. Used by the UI to distinguish "no cafes in DB" from
  /// "everything failed silently".
  final bool allEmpty;

  /// The cafes this emission added to the feed. A load can emit twice (the
  /// sections that need no position, then "Near you"), and the status lookup
  /// should only ask about each cafe once. Null means all of [cafeIds].
  final Set<String>? newCafeIds;

  /// Why the last pull to refresh failed; the lists are the ones from before
  /// it. Null on every other emission, so it is reported once.
  final Object? refreshError;

  HomeLoadedState({
    required this.featuredCafes,
    this.nearbyCafes = const [],
    required this.newestCafes,
    required this.trendingCafes,
    required this.topRatedCafes,
    this.specialtyNearbyCafes = const [],
    this.laptopFriendlyCafes = const [],
    this.locationDenied = false,
    this.locationServicesOff = false,
    this.locationBannerDismissed = false,
    this.allEmpty = false,
    this.newCafeIds,
    this.refreshError,
  });

  /// Every cafe on the feed, for the one batched status lookup.
  Set<String> get cafeIds => {
    for (final cafe in featuredCafes) cafe.id,
    for (final cafe in nearbyCafes) cafe.id,
    for (final cafe in newestCafes) cafe.id,
    for (final cafe in trendingCafes) cafe.id,
    for (final cafe in topRatedCafes) cafe.id,
    for (final cafe in specialtyNearbyCafes) cafe.id,
    for (final cafe in laptopFriendlyCafes) cafe.id,
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
    List<CafeSummary>? specialtyNearbyCafes,
    List<CafeSummary>? laptopFriendlyCafes,
    bool? locationDenied,
    bool? locationServicesOff,
    bool? locationBannerDismissed,
    bool? allEmpty,
    Set<String>? newCafeIds,
    Object? refreshError,
  }) {
    return HomeLoadedState(
      featuredCafes: featuredCafes ?? this.featuredCafes,
      nearbyCafes: nearbyCafes ?? this.nearbyCafes,
      newestCafes: newestCafes ?? this.newestCafes,
      trendingCafes: trendingCafes ?? this.trendingCafes,
      topRatedCafes: topRatedCafes ?? this.topRatedCafes,
      specialtyNearbyCafes: specialtyNearbyCafes ?? this.specialtyNearbyCafes,
      laptopFriendlyCafes: laptopFriendlyCafes ?? this.laptopFriendlyCafes,
      locationDenied: locationDenied ?? this.locationDenied,
      locationServicesOff: locationServicesOff ?? this.locationServicesOff,
      locationBannerDismissed:
          locationBannerDismissed ?? this.locationBannerDismissed,
      allEmpty: allEmpty ?? this.allEmpty,
      newCafeIds: newCafeIds ?? this.newCafeIds,
      refreshError: refreshError,
    );
  }
}

class HomeError extends HomeState {
  final Object error;

  HomeError(this.error);
}
