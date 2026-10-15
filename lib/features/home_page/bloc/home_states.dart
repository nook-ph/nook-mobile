import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';

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

  /// Cafes tagged Philippine Beans; empty below [minLocalBeans].
  final List<CafeSummary> localBeansCafes;

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

  /// What the user said they are looking for at onboarding; its shelf
  /// leads the feed. Null for anyone who never answered.
  final OnboardingPurpose? purpose;

  /// The published Home layout, or null for the built-in Home.
  final HomeLayout? layout;

  /// The cafes [layout] adds, by section id: hand-picked House picks
  /// (`featured`) and custom shelves. A section missing here failed to load.
  final Map<String, List<CafeSummary>> layoutShelves;

  HomeLoadedState({
    required this.featuredCafes,
    this.nearbyCafes = const [],
    required this.newestCafes,
    required this.trendingCafes,
    required this.topRatedCafes,
    this.specialtyNearbyCafes = const [],
    this.laptopFriendlyCafes = const [],
    this.localBeansCafes = const [],
    this.locationDenied = false,
    this.locationServicesOff = false,
    this.locationBannerDismissed = false,
    this.allEmpty = false,
    this.newCafeIds,
    this.refreshError,
    this.purpose,
    this.layout,
    this.layoutShelves = const {},
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
    for (final cafe in localBeansCafes) cafe.id,
    for (final cafes in layoutShelves.values)
      for (final cafe in cafes) cafe.id,
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
    List<CafeSummary>? localBeansCafes,
    bool? locationDenied,
    bool? locationServicesOff,
    bool? locationBannerDismissed,
    bool? allEmpty,
    Set<String>? newCafeIds,
    Object? refreshError,
    OnboardingPurpose? purpose,
    HomeLayout? layout,
    Map<String, List<CafeSummary>>? layoutShelves,

    /// Back to the built-in Home ([layout] null).
    bool clearLayout = false,
  }) {
    return HomeLoadedState(
      featuredCafes: featuredCafes ?? this.featuredCafes,
      nearbyCafes: nearbyCafes ?? this.nearbyCafes,
      newestCafes: newestCafes ?? this.newestCafes,
      trendingCafes: trendingCafes ?? this.trendingCafes,
      topRatedCafes: topRatedCafes ?? this.topRatedCafes,
      specialtyNearbyCafes: specialtyNearbyCafes ?? this.specialtyNearbyCafes,
      laptopFriendlyCafes: laptopFriendlyCafes ?? this.laptopFriendlyCafes,
      localBeansCafes: localBeansCafes ?? this.localBeansCafes,
      locationDenied: locationDenied ?? this.locationDenied,
      locationServicesOff: locationServicesOff ?? this.locationServicesOff,
      locationBannerDismissed:
          locationBannerDismissed ?? this.locationBannerDismissed,
      allEmpty: allEmpty ?? this.allEmpty,
      newCafeIds: newCafeIds ?? this.newCafeIds,
      refreshError: refreshError,
      purpose: purpose ?? this.purpose,
      layout: clearLayout ? null : (layout ?? this.layout),
      layoutShelves: clearLayout
          ? const {}
          : (layoutShelves ?? this.layoutShelves),
    );
  }
}

class HomeError extends HomeState {
  final Object error;

  HomeError(this.error);
}
