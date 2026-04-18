import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

abstract class HomeState {}

class HomeInitialState extends HomeState {}

class HomeLoadingState extends HomeState {}

class HomeLoadedState extends HomeState {
  final List<CafeSummary> featuredCafes;
  final List<CafeSummary> newestCafes;
  final List<CafeSummary> trendingCafes;
  final List<CafeSummary> topRatedCafes;

  HomeLoadedState({
    required this.featuredCafes,
    required this.newestCafes,
    required this.trendingCafes,
    required this.topRatedCafes,
  });
}

class HomeError extends HomeState {
  final String message;

  HomeError(this.message);
}
