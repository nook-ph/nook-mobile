import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/utils/geo.dart';

void main() {
  group('haversineMeters', () {
    test('is zero for identical points', () {
      const p = GeoPoint(lat: 10.3167, lng: 123.8907);
      expect(haversineMeters(p, p), 0);
    });

    test('one degree of longitude at the equator is ~111.19 km', () {
      const a = GeoPoint(lat: 0, lng: 0);
      const b = GeoPoint(lat: 0, lng: 1);
      expect(haversineMeters(a, b), closeTo(111195, 200));
    });

    test('is symmetric', () {
      const a = GeoPoint(lat: 10.3, lng: 123.9);
      const b = GeoPoint(lat: 10.4, lng: 124.0);
      expect(haversineMeters(a, b), closeTo(haversineMeters(b, a), 0.0001));
    });
  });

  group('viewportRadiusMeters', () {
    test('measures center to the north-east corner', () {
      const viewport = MapViewport(
        center: GeoPoint(lat: 10.0, lng: 123.0),
        bounds: MapBounds(north: 10.1, east: 123.1, south: 9.9, west: 122.9),
        zoom: 12,
      );
      final expected = haversineMeters(
        const GeoPoint(lat: 10.0, lng: 123.0),
        const GeoPoint(lat: 10.1, lng: 123.1),
      );
      expect(viewportRadiusMeters(viewport), expected);
    });

    test('grows as the viewport gets bigger', () {
      const small = MapViewport(
        center: GeoPoint(lat: 10.0, lng: 123.0),
        bounds: MapBounds(
          north: 10.01,
          east: 123.01,
          south: 9.99,
          west: 122.99,
        ),
        zoom: 15,
      );
      const large = MapViewport(
        center: GeoPoint(lat: 10.0, lng: 123.0),
        bounds: MapBounds(north: 10.5, east: 123.5, south: 9.5, west: 122.5),
        zoom: 8,
      );
      expect(
        viewportRadiusMeters(small),
        lessThan(viewportRadiusMeters(large)),
      );
    });
  });
}
