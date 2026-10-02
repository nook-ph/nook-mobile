import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_route_map.dart';

import 'crawl_fixtures.dart';

void main() {
  const card = Size(350, 180);

  group('CrawlRouteMap.fitCamera', () {
    test('centres on the stops and zooms to hold them', () {
      final camera = CrawlRouteMap.fitCamera([
        stop(1, lat: 10.330, lng: 123.900),
        stop(2, lat: 10.334, lng: 123.906),
      ], card);

      expect(camera.target.latitude, closeTo(10.332, 1e-4));
      expect(camera.target.longitude, closeTo(123.903, 1e-9));
      // The card is short, so the 0.004 degrees of latitude across its 120
      // points of height set the zoom, not the width.
      expect(camera.zoom, closeTo(14.34, 0.05));
    });

    test('stops on one point get a fixed zoom, not an infinite one', () {
      final camera = CrawlRouteMap.fitCamera([stop(1), stop(2)], card);

      expect(camera.target.latitude, closeTo(10.33, 1e-9));
      expect(camera.zoom, 15.5);
    });

    test('a card with no room still gives a finite camera', () {
      final camera = CrawlRouteMap.fitCamera([
        stop(1, lat: 10.330, lng: 123.900),
        stop(2, lat: 10.334, lng: 123.906),
      ], Size.zero);

      expect(camera.zoom.isFinite, isTrue);
      expect(camera.target.latitude.isFinite, isTrue);
    });
  });
}
