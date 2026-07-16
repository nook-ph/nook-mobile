import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// Geographic + viewport helpers shared by the map feature.
/// Port of the webapp's `lib/utils/maps.ts`.

class GeoPoint extends Equatable {
  final double lat;
  final double lng;

  const GeoPoint({required this.lat, required this.lng});

  @override
  List<Object?> get props => [lat, lng];
}

class MapBounds extends Equatable {
  final double north;
  final double east;
  final double south;
  final double west;

  const MapBounds({
    required this.north,
    required this.east,
    required this.south,
    required this.west,
  });

  @override
  List<Object?> get props => [north, east, south, west];
}

class MapViewport extends Equatable {
  final GeoPoint center;
  final MapBounds bounds;
  final double zoom;

  const MapViewport({
    required this.center,
    required this.bounds,
    required this.zoom,
  });

  @override
  List<Object?> get props => [center, bounds, zoom];
}

/// Great-circle distance between two points, in meters.
double haversineMeters(GeoPoint a, GeoPoint b) {
  const earthRadius = 6371000.0;
  double toRad(double deg) => deg * math.pi / 180;
  final dLat = toRad(b.lat - a.lat);
  final dLng = toRad(b.lng - a.lng);
  final lat1 = toRad(a.lat);
  final lat2 = toRad(b.lat);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
}

/// Radius (meters) from a viewport's center to its farthest corner. Used to
/// decide whether the visible area fits inside a fixed search radius.
double viewportRadiusMeters(MapViewport viewport) {
  return haversineMeters(
    viewport.center,
    GeoPoint(lat: viewport.bounds.north, lng: viewport.bounds.east),
  );
}
