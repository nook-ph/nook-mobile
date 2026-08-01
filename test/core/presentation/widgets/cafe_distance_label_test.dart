import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/widgets/cafe_distance_label.dart';

/// Nook covers one metro, so a distance in the thousands of kilometres is a
/// stale or wrong fix rather than a fact about the cafe. The details header
/// used to render "11356.6 km" beside a Cebu cafe as though it were useful.
void main() {
  group('formatDistanceMeters', () {
    test('shows metres below a kilometre', () {
      expect(formatDistanceMeters(0), '0 m');
      expect(formatDistanceMeters(1), '1 m');
      expect(formatDistanceMeters(450.4), '450 m');
      expect(formatDistanceMeters(999), '999 m');
    });

    test('switches to one-decimal kilometres at and above 1km', () {
      expect(formatDistanceMeters(1000), '1.0 km');
      expect(formatDistanceMeters(5800), '5.8 km');
      expect(formatDistanceMeters(20000), '20.0 km');
    });

    test('keeps anything within the metro and its surrounds', () {
      // Far end of Cebu province is well inside the bound.
      expect(formatDistanceMeters(150000), '150.0 km');
      expect(formatDistanceMeters(300000), '300.0 km');
    });

    test('shows nothing once the reading stops being about this metro', () {
      // The emulator's US fix produced roughly this.
      expect(formatDistanceMeters(11356600), isNull);
      expect(formatDistanceMeters(300001), isNull);
    });

    test('shows nothing for impossible values', () {
      expect(formatDistanceMeters(-1), isNull);
      expect(formatDistanceMeters(double.nan), isNull);
      expect(formatDistanceMeters(double.infinity), isNull);
    });
  });
}
