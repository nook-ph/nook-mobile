import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';

abstract class MapState {}

class MapInitialState extends MapState {}

class MapLoadingState extends MapState {}

class MapLoadedState extends MapState {
  final List<CafeSummary> cafes;
  final List<CafeTagsEntity> tags;

  MapLoadedState({
    required this.cafes,
    required this.tags,
  });
}

class MapError extends MapState {
  final String message;

  MapError(this.message);
}
