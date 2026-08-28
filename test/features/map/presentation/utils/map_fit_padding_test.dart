import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/map/presentation/utils/map_fit_padding.dart';

void main() {
  group('resolveMapFitPadding', () {
    test('leaves padding alone when the map is big enough for it', () {
      final padding = resolveMapFitPadding(
        viewport: const Size(393, 769),
        left: 40,
        top: 60,
        right: 40,
        bottom: 407,
      );

      expect(padding.left, 40);
      expect(padding.top, 60);
      expect(padding.right, 40);
      expect(padding.bottom, 407);
    });

    test('shrinks padding that would leave the map nothing to fit into', () {
      // The crash: an expanded sheet reports ~740pt of occlusion, so the
      // bottom inset alone is nearly the height of the map.
      const viewport = Size(393, 769);
      final padding = resolveMapFitPadding(
        viewport: viewport,
        left: 40,
        top: 60,
        right: 40,
        bottom: 764,
      );

      expect(
        padding.top + padding.bottom,
        lessThanOrEqualTo(viewport.height - kMinFitViewportExtent),
      );
      expect(
        viewport.height - padding.top - padding.bottom,
        greaterThanOrEqualTo(kMinFitViewportExtent),
      );
    });

    test('keeps the bottom inset the largest one when it shrinks', () {
      // Scaling both sides together is the point: the bottom inset exists to
      // clear the sheet, and that intent has to survive the clamp.
      final padding = resolveMapFitPadding(
        viewport: const Size(393, 769),
        left: 40,
        top: 60,
        right: 40,
        bottom: 764,
      );

      expect(padding.bottom, greaterThan(padding.top));
      expect(padding.bottom / padding.top, closeTo(764 / 60, 0.01));
    });

    test('clamps each axis independently', () {
      final padding = resolveMapFitPadding(
        viewport: const Size(393, 769),
        left: 300,
        top: 60,
        right: 300,
        bottom: 407,
      );

      expect(padding.left + padding.right, lessThanOrEqualTo(393 - 80));
      // The vertical axis had room, so it is untouched.
      expect(padding.top, 60);
      expect(padding.bottom, 407);
    });

    test('gives up rather than guessing when the map has no size', () {
      for (final viewport in const [
        Size.zero,
        Size(0, 769),
        Size(393, 0),
        Size(393, double.infinity),
      ]) {
        final padding = resolveMapFitPadding(
          viewport: viewport,
          left: 40,
          top: 60,
          right: 40,
          bottom: 407,
        );
        final axisIsUnusable =
            viewport.height <= 0 || !viewport.height.isFinite;
        if (axisIsUnusable) {
          expect(padding.top, 0, reason: '$viewport');
          expect(padding.bottom, 0, reason: '$viewport');
        }
        if (viewport.width <= 0) {
          expect(padding.left, 0, reason: '$viewport');
          expect(padding.right, 0, reason: '$viewport');
        }
      }
    });

    test('yields nothing when the map is smaller than the minimum strip', () {
      final padding = resolveMapFitPadding(
        viewport: const Size(40, 40),
        left: 40,
        top: 60,
        right: 40,
        bottom: 407,
      );

      expect(padding.left, 0);
      expect(padding.top, 0);
      expect(padding.right, 0);
      expect(padding.bottom, 0);
    });

    test('treats negative and non-finite insets as no inset', () {
      final padding = resolveMapFitPadding(
        viewport: const Size(393, 769),
        left: -40,
        top: double.nan,
        right: double.infinity,
        bottom: 100,
      );

      expect(padding.left, 0);
      expect(padding.top, 0);
      expect(padding.right, 0);
      expect(padding.bottom, 100);
    });

    test('never returns padding that exceeds the viewport, at any size', () {
      for (var height = 1.0; height <= 1200; height += 7) {
        final padding = resolveMapFitPadding(
          viewport: Size(393, height),
          left: 40,
          top: 60,
          right: 40,
          bottom: height * 0.45 + 24,
        );

        expect(
          padding.top + padding.bottom,
          lessThanOrEqualTo(height),
          reason: 'height $height',
        );
        expect(padding.top.isFinite && padding.bottom.isFinite, isTrue);
        expect(padding.top, greaterThanOrEqualTo(0));
        expect(padding.bottom, greaterThanOrEqualTo(0));
      }
    });
  });
}
