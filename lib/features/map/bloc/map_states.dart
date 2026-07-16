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

  /// True while a viewport/filter refetch is in flight. The previous [cafes]
  /// stay visible; the UI shows a small "Updating" chip instead of a skeleton.
  final bool isRefreshing;

  MapLoadedState({
    required this.cafes,
    required this.tags,
    this.locationDenied = false,
    this.locationBannerDismissed = false,
    this.isRefreshing = false,
  });

  MapLoadedState copyWith({
    List<CafeSummary>? cafes,
    List<CafeTagsEntity>? tags,
    bool? locationDenied,
    bool? locationBannerDismissed,
    bool? isRefreshing,
  }) {
    return MapLoadedState(
      cafes: cafes ?? this.cafes,
      tags: tags ?? this.tags,
      locationDenied: locationDenied ?? this.locationDenied,
      locationBannerDismissed:
          locationBannerDismissed ?? this.locationBannerDismissed,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class MapError extends MapState {
  final Object error;

  MapError(this.error);
}
