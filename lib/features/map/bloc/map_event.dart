import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/core/utils/geo.dart';

abstract class MapEvent {}

class LoadMapDataEvent extends MapEvent {
  final CafeFilter filter;
  LoadMapDataEvent({this.filter = const CafeFilter()});
}

/// The camera settled on a new viewport; refetch the cafes in view.
class MapViewportChangedEvent extends MapEvent {
  final MapViewport viewport;
  MapViewportChangedEvent(this.viewport);
}

class LoadFilterTagsEvent extends MapEvent {}

class MapDismissLocationBannerEvent extends MapEvent {}
