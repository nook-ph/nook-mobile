import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';

abstract class MapState {}

class MapInitialState extends MapState {}

class MapLoadingState extends MapState {}

class MapLoadedState extends MapState {
  final List<CafeSummary> cafes;
  final List<CafeTagsEntity> tags;
  final bool locationDenied;
  final bool locationBannerDismissed;

  MapLoadedState({
    required this.cafes,
    required this.tags,
    this.locationDenied = false,
    this.locationBannerDismissed = false,
  });

  MapLoadedState copyWith({
    List<CafeSummary>? cafes,
    List<CafeTagsEntity>? tags,
    bool? locationDenied,
    bool? locationBannerDismissed,
  }) {
    return MapLoadedState(
      cafes: cafes ?? this.cafes,
      tags: tags ?? this.tags,
      locationDenied: locationDenied ?? this.locationDenied,
      locationBannerDismissed:
          locationBannerDismissed ?? this.locationBannerDismissed,
    );
  }
}

class MapError extends MapState {
  final Object error;

  MapError(this.error);
}
