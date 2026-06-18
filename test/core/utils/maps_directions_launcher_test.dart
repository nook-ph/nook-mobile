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
}
