import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/map/presentation/utils/map_camera_fit.dart';
import 'package:nook/features/map/presentation/utils/map_fit_padding.dart';

/// The real figures from the crashing device: iPhone 15, map 393x755, the
/// bounds of all 54 Cebu cafes.
const _viewport = Size(393, 755);
const _south = 10.017654314421;
const _west = 123.620905950888;
const _north = 10.6339699038454;
const _east = 124.028320798937;

MapCameraFit? _fitWith(MapFitPadding padding, {Size viewport = _viewport}) {
  return resolveMapCameraFit(
    southLatitude: _south,
    westLongitude: _west,
    northLatitude: _north,
    eastLongitude: _east,
    viewport: viewport,
    padding: padding,
  );
}

void main() {
  group('resolveMapCameraFit', () {
    test('produces a finite camera for the geometry that crashed', () {
      final fit = _fitWith(
        const MapFitPadding(left: 40, top: 60, right: 40, bottom: 530.4),
      );

      expect(fit, isNotNull);
      expect(fit!.latitude.isFinite, isTrue);
      expect(fit.longitude.isFinite, isTrue);
      expect(fit.zoom.isFinite, isTrue);
      // Metro-wide, not the whole planet and not a single street.
      expect(fit.zoom, inInclusiveRange(6, 14));
      expect(fit.latitude, inInclusiveRange(-85, 85));
      expect(fit.longitude, inInclusiveRange(-180, 180));
    });

    test('centres on the bounds when the padding is symmetric', () {
      final fit = _fitWith(
        const MapFitPadding(left: 40, top: 40, right: 40, bottom: 40),
      );

      expect(fit!.latitude, closeTo((_south + _north) / 2, 0.02));
      expect(fit.longitude, closeTo((_west + _east) / 2, 0.001));
    });

    test('sits south of the bounds so the pins clear the sheet', () {
      // A bottom inset larger than the top one means the visible strip is the
      // upper part of the map. The camera has to move south for the bounds to
      // rise into it.
      final centred = _fitWith(
        const MapFitPadding(left: 40, top: 40, right: 40, bottom: 40),
      )!;
      final sheeted = _fitWith(
        const MapFitPadding(left: 40, top: 60, right: 40, bottom: 530.4),
      )!;

      expect(sheeted.latitude, lessThan(centred.latitude));
    });

    test('zooms out further as the sheet takes more of the map', () {
      final roomy = _fitWith(
        const MapFitPadding(left: 40, top: 60, right: 40, bottom: 100),
      )!;
      final cramped = _fitWith(
        const MapFitPadding(left: 40, top: 60, right: 40, bottom: 530.4),
      )!;

      expect(cramped.zoom, lessThan(roomy.zoom));
    });

    test('handles a single pin, where both spans are zero', () {
      final fit = resolveMapCameraFit(
        southLatitude: 10.3,
        westLongitude: 123.9,
        northLatitude: 10.3,
        eastLongitude: 123.9,
        viewport: _viewport,
        padding: const MapFitPadding(left: 40, top: 60, right: 40, bottom: 300),
      );

      expect(fit, isNotNull);
      expect(fit!.zoom, 18.0);
      expect(fit.longitude, closeTo(123.9, 0.001));
    });

    test('declines rather than returning a broken camera', () {
      // Padding wider than the map, an unmeasured viewport, and NaN bounds all
      // have to yield null — every one of them used to reach MapLibre as a NaN
      // and abort the process.
      expect(
        _fitWith(
          const MapFitPadding(left: 40, top: 500, right: 40, bottom: 500),
        ),
        isNull,
      );
      expect(
        _fitWith(
          const MapFitPadding(left: 40, top: 60, right: 40, bottom: 100),
          viewport: Size.zero,
        ),
        isNull,
      );
      expect(
        resolveMapCameraFit(
          southLatitude: double.nan,
          westLongitude: _west,
          northLatitude: _north,
          eastLongitude: _east,
          viewport: _viewport,
          padding: const MapFitPadding(
            left: 40,
            top: 60,
            right: 40,
            bottom: 100,
          ),
        ),
        isNull,
      );
    });

    test('never yields a non-finite camera across a sweep of viewports', () {
      for (var height = 200.0; height <= 1200; height += 13) {
        final padding = resolveMapFitPadding(
          viewport: Size(393, height),
          left: 40,
          top: 60,
          right: 40,
          bottom: height * 0.45 + 24,
        );
        final fit = _fitWith(padding, viewport: Size(393, height));

        expect(fit, isNotNull, reason: 'height $height');
        expect(fit!.zoom.isFinite, isTrue, reason: 'height $height');
        expect(fit.latitude.isFinite, isTrue, reason: 'height $height');
        expect(fit.longitude.isFinite, isTrue, reason: 'height $height');
        expect(fit.zoom, inInclusiveRange(1, 18), reason: 'height $height');
      }
    });
  });
}
