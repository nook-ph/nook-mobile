import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

sealed class CrawlStopsMapState {}

class CrawlStopsMapInitial extends CrawlStopsMapState {}

class CrawlStopsMapLoading extends CrawlStopsMapState {}

class CrawlStopsMapLoaded extends CrawlStopsMapState {
  final Map<String, CafeSummary> cafeById;
  final List<CafeSummary> cafes;

  CrawlStopsMapLoaded({required this.cafeById, required this.cafes});
}

class CrawlStopsMapError extends CrawlStopsMapState {
  final Object error;

  CrawlStopsMapError(this.error);
}
