import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';

abstract class HomeState {}

class HomeInitialState extends HomeState {}

class HomeLoadingState extends HomeState {}

class HomeLoadedState extends HomeState {
  final List<CafeSummaryEntity> featuredCafes;
  final List<CafeSummaryEntity> newestCafes;
  final List<CafeSummaryEntity> trendingCafes;
  final List<CafeSummaryEntity> topRatedCafes;

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
