import 'package:nook/core/utils/geo.dart';

/// Where Nook has cafes: Metro Cebu, with a margin so the edge towns
/// (Carcar, Danao, Cordova) still count as inside.
///
/// Used only to change the copy of an empty result: "No cafes in this area"
/// reads as a broken app to someone in Manila, who should hear that Nook is
/// Cebu-only for now.
abstract final class CebuCoverage {
  static const bounds = MapBounds(
    north: 10.65,
    south: 10.0,
    west: 123.55,
    east: 124.15,
  );

  static bool contains(GeoPoint point) =>
      point.lat >= bounds.south &&
      point.lat <= bounds.north &&
      point.lng >= bounds.west &&
      point.lng <= bounds.east;

  /// Whether the user is clearly outside Cebu.
  ///
  /// With a [device] position, the device decides, but not while the user is
  /// [viewing] Cebu (someone in Manila planning a trip who filtered the map
  /// to nothing is not asking for Manila). Without one, the place being
  /// viewed decides (the map's centre, search's chosen place). With neither
  /// there is nothing to go on, so no.
  static bool isOutside({GeoPoint? device, GeoPoint? viewing}) {
    if (device != null) {
      return !contains(device) && (viewing == null || !contains(viewing));
    }
    if (viewing != null) return !contains(viewing);
    return false;
  }
}
