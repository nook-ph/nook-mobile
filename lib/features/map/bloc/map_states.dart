import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

abstract class MapState {}

class MapInitialState extends MapState {}

class MapLoadingState extends MapState {}

class MapLoadedState extends MapState {
  final List<CafeSummary> cafes;

  MapLoadedState({
    required this.cafes,
  });
}

class MapError extends MapState {
  final String message;

  MapError(this.message);
}
