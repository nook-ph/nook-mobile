import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:nook/features/map/presentation/utils/map_fit_padding.dart';

/// A camera that frames a set of bounds inside the unobscured part of the map.
class MapCameraFit {
  const MapCameraFit({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final double latitude;
  final double longitude;
  final double zoom;

  @override
  String toString() =>
      'MapCameraFit(lat: $latitude, lng: $longitude, zoom: $zoom)';
}

/// MapLibre defines zoom against a 512px tile.
const double _tileSize = 512.0;

/// Solves the fit-to-bounds camera in Dart, rather than asking MapLibre for it.
///
/// Two things about the iOS side made the obvious call unusable, and both were
/// found by tracing a release build on device (see the commit message).
///
/// The first is why this function exists rather than
/// `CameraUpdate.newLatLngBounds`: that lands in
/// `cameraThatFitsCoordinateBounds:edgePadding:`, which adds the map view's own
/// `contentInset` to whatever padding we pass before solving. That inset is
/// invisible from Dart, and on a Flutter platform view it arrives through the
/// deprecated `automaticallyAdjustsScrollViewInsets` path the console warns
/// about at every map creation. Computing the camera here means the framing
/// depends only on numbers we can see and test.
///
/// The second is why the caller applies the result with `moveCamera` and a
/// `newCameraPosition` update. Every camera update lands in
/// `-[MLNMapView setCamera:...]`, and mbgl throws `std::domain_error` there on
/// a NaN or out-of-range coordinate — with a camera this function had already
/// proved finite (lat 10.08, lng 123.82, zoom 8.73). The exception unwinds
/// through the method channel into `std::terminate`, so no Dart `try` can catch
/// it: the process aborts with SIGABRT and the app vanishes with no error
/// screen. Swapping `animateCamera` for `moveCamera` did not settle it — 1.1.1
/// still aborted on 30 Aug — because the NaN comes from the plugin reading the
/// *native* camera and view size, not from the numbers computed here. See
/// `_fitCameraToCafes` for which reads were removed.
///
/// Returns null when the geometry cannot produce a usable camera, in which case
/// the caller should leave the camera where it is rather than guess.
MapCameraFit? resolveMapCameraFit({
  required double southLatitude,
  required double westLongitude,
  required double northLatitude,
  required double eastLongitude,
  required Size viewport,
  required MapFitPadding padding,
  double minZoom = 1.0,
  double maxZoom = 18.0,
}) {
  if (!viewport.width.isFinite ||
      !viewport.height.isFinite ||
      viewport.width <= 0 ||
      viewport.height <= 0) {
    return null;
  }
  if (![
    southLatitude,
    westLongitude,
    northLatitude,
    eastLongitude,
  ].every((value) => value.isFinite)) {
    return null;
  }

  final south = southLatitude.clamp(-85.0, 85.0);
  final north = northLatitude.clamp(-85.0, 85.0);
  final west = westLongitude.clamp(-180.0, 180.0);
  final east = eastLongitude.clamp(-180.0, 180.0);

  final availableWidth = viewport.width - padding.left - padding.right;
  final availableHeight = viewport.height - padding.top - padding.bottom;
  if (availableWidth <= 0 || availableHeight <= 0) return null;

  // A span of zero — one pin, or a degenerate box — would divide by zero on the
  // way to a zoom. Treat it as "as close as we are allowed to go".
  final westX = _normalizedX(west);
  final eastX = _normalizedX(east);
  final southY = _normalizedY(south);
  final northY = _normalizedY(north);

  final spanX = (eastX - westX).abs();
  final spanY = (southY - northY).abs();

  final zoomForWidth = spanX <= 0
      ? maxZoom
      : _log2(availableWidth / (_tileSize * spanX));
  final zoomForHeight = spanY <= 0
      ? maxZoom
      : _log2(availableHeight / (_tileSize * spanY));

  var zoom = math.min(zoomForWidth, zoomForHeight);
  if (!zoom.isFinite) return null;
  zoom = zoom.clamp(minZoom, maxZoom);

  final worldSize = _tileSize * math.pow(2, zoom).toDouble();
  if (!worldSize.isFinite || worldSize <= 0) return null;

  // Centre of the bounds, then pushed so it lands in the middle of the part of
  // the map that is not behind the sheet rather than the middle of the map.
  // Screen y grows downward, so a bottom inset larger than the top one puts the
  // visible centre above the map's centre and the camera has to sit south of
  // the bounds for them to rise above the sheet.
  final offsetX = (padding.left - padding.right) / 2;
  final offsetY = (padding.top - padding.bottom) / 2;

  final centreX = (westX + eastX) / 2 - offsetX / worldSize;
  final centreY = (southY + northY) / 2 - offsetY / worldSize;

  final longitude = (centreX - 0.5) * 360.0;
  final latitude = _latitudeFor(centreY);

  if (!longitude.isFinite || !latitude.isFinite) return null;

  return MapCameraFit(
    latitude: latitude.clamp(-85.0, 85.0),
    longitude: longitude.clamp(-180.0, 180.0),
    zoom: zoom,
  );
}

/// Longitude to a 0..1 fraction of the world, west to east.
double _normalizedX(double longitude) => longitude / 360.0 + 0.5;

/// Latitude to a 0..1 fraction of the world, north to south (Web Mercator).
double _normalizedY(double latitude) {
  final radians = latitude * math.pi / 180.0;
  final projected = math.log(math.tan(math.pi / 4 + radians / 2));
  return 0.5 - projected / (2 * math.pi);
}

/// Inverse of [_normalizedY].
double _latitudeFor(double normalizedY) {
  final projected = (0.5 - normalizedY) * 2 * math.pi;
  return (2 * math.atan(_exp(projected)) - math.pi / 2) * 180.0 / math.pi;
}

double _exp(double value) => math.exp(value);

double _log2(double value) =>
    value <= 0 ? double.negativeInfinity : math.log(value) / math.ln2;
