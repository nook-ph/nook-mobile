import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

enum MapsAppChoice { googleMaps, appleMaps }

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
    MapsAppChoice? preferredApp,
  }) async {
    debugPrint(
      '[DirectionsLauncher] launchDirections called | lat=$lat lng=$lng | '
      'label="$label" platform=$platform preferredApp=$preferredApp',
    );
    final uris = buildLaunchUris(
      lat: lat,
      lng: lng,
      label: label,
      platform: platform,
      preferredApp: preferredApp,
    );
    debugPrint('[DirectionsLauncher] URI candidates: $uris');

    for (final uri in uris) {
      final canLaunch = await canLaunchUrl(uri);
      debugPrint(
        '[DirectionsLauncher] Checking URI | uri=$uri canLaunch=$canLaunch',
      );
      if (canLaunch) {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        debugPrint(
          '[DirectionsLauncher] launchUrl result | uri=$uri launched=$launched',
        );
        if (launched) {
          debugPrint('[DirectionsLauncher] Success with URI: $uri');
          return true;
        }
      }
    }

    debugPrint('[DirectionsLauncher] Failed to launch any directions URI');
    return false;
  }

  static List<Uri> buildLaunchUris({
    required double lat,
    required double lng,
    required String label,
    required TargetPlatform platform,
    MapsAppChoice? preferredApp,
  }) {
    final resolvedLabel = label.trim().isEmpty ? 'Destination' : label.trim();
    final encodedLabel = Uri.encodeComponent(resolvedLabel);

    final googleMapsAppUri = Uri.parse(
      'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving&q=$encodedLabel',
    );

    final appleMapsUri = Uri.parse(
      'http://maps.apple.com/?daddr=$lat,$lng&q=$encodedLabel&dirflg=d',
    );

    final googleMapsWebUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );

    final List<Uri> uris;
    if (platform == TargetPlatform.iOS) {
      if (preferredApp == MapsAppChoice.googleMaps) {
        uris = [googleMapsAppUri, googleMapsWebUri];
      } else {
        uris = [appleMapsUri, googleMapsAppUri, googleMapsWebUri];
      }
    } else {
      uris = [googleMapsAppUri, googleMapsWebUri];
    }

    debugPrint(
      '[DirectionsLauncher] buildLaunchUris | platform=$platform '
      'preferredApp=$preferredApp resolvedLabel="$resolvedLabel" uris=$uris',
    );

    return uris;
  }
}
