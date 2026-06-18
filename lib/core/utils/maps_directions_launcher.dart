import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:map_launcher/map_launcher.dart';

class MapsDirectionsLauncher {
  const MapsDirectionsLauncher._();

  static bool hasValidCoordinates(double lat, double lng) {
    final latInRange = lat >= -90 && lat <= 90;
    final lngInRange = lng >= -180 && lng <= 180;

    // (0,0) is often a placeholder for unknown coordinates.
    final isLikelyPlaceholder = lat == 0 && lng == 0;
    final isValid = latInRange && lngInRange && !isLikelyPlaceholder;

    debugPrint(
      '[DirectionsLauncher] Coordinate validation | lat=$lat lng=$lng | '
      'latInRange=$latInRange lngInRange=$lngInRange '
      'placeholder=$isLikelyPlaceholder valid=$isValid',
    );

    return isValid;
  }

  static Future<bool> launchDirections({
    required double lat,
    required double lng,
    required String label,
    required TargetPlatform platform,
  }) async {
    final resolvedLabel = label.trim().isEmpty ? 'Destination' : label.trim();
    final destination = Coords(lat, lng);

    debugPrint(
      '[DirectionsLauncher] launchDirections called | lat=$lat lng=$lng | '
      'label="$resolvedLabel" platform=$platform',
    );

    final mapType = platform == TargetPlatform.iOS
        ? MapType.apple
        : MapType.google;

    try {
      final isAvailable = await MapLauncher.isMapAvailable(mapType);
      debugPrint(
        '[DirectionsLauncher] isMapAvailable | mapType=$mapType '
        'available=$isAvailable',
      );
      if (!isAvailable) {
        debugPrint('[DirectionsLauncher] Selected map not available');
        return false;
      }

      await MapLauncher.showDirections(
        mapType: mapType,
        destination: destination,
        destinationTitle: resolvedLabel,
        directionsMode: DirectionsMode.driving,
      );
      debugPrint('[DirectionsLauncher] showDirections succeeded');
      return true;
    } on PlatformException catch (e) {
      debugPrint(
        '[DirectionsLauncher] PlatformException | code=${e.code} '
        'message=${e.message}',
      );
      return false;
    } on MissingPluginException catch (e) {
      debugPrint(
        '[DirectionsLauncher] MissingPluginException | message=${e.message}',
      );
      return false;
    }
  }
}
