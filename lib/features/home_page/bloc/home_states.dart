import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';

abstract class HomeState {}

class HomeInitialState extends HomeState {}
class HomeLoadingState extends HomeState {}
class HomeLoadedState extends HomeState {
  final List<CafeSummaryEntity> featuredCafes;
  final List<CafeSummaryEntity> recommendedCafes;

  HomeLoadedState({
    required this.featuredCafes,
    required this.recommendedCafes,
  });
}

class HomeError extends HomeState {
  final String message;

  HomeError(this.message);
}