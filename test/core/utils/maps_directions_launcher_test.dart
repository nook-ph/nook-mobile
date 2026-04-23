import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/utils/maps_directions_launcher.dart';

void main() {
  group('MapsDirectionsLauncher.hasValidCoordinates', () {
    test('returns true for valid non-zero coordinates', () {
      expect(
        MapsDirectionsLauncher.hasValidCoordinates(14.5995, 120.9842),
        isTrue,
      );
    });

    test('returns false for zero placeholder coordinates', () {
      expect(MapsDirectionsLauncher.hasValidCoordinates(0, 0), isFalse);
    });

    test('returns false for out-of-range coordinates', () {
      expect(MapsDirectionsLauncher.hasValidCoordinates(120, 120), isFalse);
      expect(MapsDirectionsLauncher.hasValidCoordinates(45, 190), isFalse);
    });
  });

  group('MapsDirectionsLauncher.buildLaunchUris', () {
    test('android starts with Google Maps app then web fallback', () {
      final uris = MapsDirectionsLauncher.buildLaunchUris(
        lat: 14.555,
        lng: 121.024,
        label: 'Nook Cafe',
        platform: TargetPlatform.android,
      );

      expect(uris, hasLength(2));
      expect(uris.first.scheme, equals('comgooglemaps'));
      expect(uris.last.toString(), contains('https://www.google.com/maps/dir/'));
    });

    test('ios Apple choice starts with Apple Maps', () {
      final uris = MapsDirectionsLauncher.buildLaunchUris(
        lat: 14.555,
        lng: 121.024,
        label: 'Nook Cafe',
        platform: TargetPlatform.iOS,
        preferredApp: MapsAppChoice.appleMaps,
      );

      expect(uris, hasLength(3));
      expect(uris.first.toString(), startsWith('http://maps.apple.com/'));
      expect(uris[1].scheme, equals('comgooglemaps'));
      expect(uris.last.toString(), contains('https://www.google.com/maps/dir/'));
    });

    test('ios Google choice skips Apple Maps URI', () {
      final uris = MapsDirectionsLauncher.buildLaunchUris(
        lat: 14.555,
        lng: 121.024,
        label: 'Nook Cafe',
        platform: TargetPlatform.iOS,
        preferredApp: MapsAppChoice.googleMaps,
      );

      expect(uris, hasLength(2));
      expect(uris.first.scheme, equals('comgooglemaps'));
      expect(uris.last.toString(), contains('https://www.google.com/maps/dir/'));
    });

    test('empty label falls back to Destination', () {
      final uris = MapsDirectionsLauncher.buildLaunchUris(
        lat: 14.555,
        lng: 121.024,
        label: '   ',
        platform: TargetPlatform.android,
      );

      expect(uris.first.toString(), contains('q=Destination'));
    });
  });
}
