import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';

void main() {
  group('CafeCardImage.decodeWidth', () {
    test('a thumbnail decodes at thumbnail size, not upload size', () {
      // 76 pt square at 3x: the height rules (76 x 1.5 x 3 = 342).
      expect(CafeCardImage.decodeWidth(const Size(76, 76), 3), 400);
    });

    test('a wide box goes by its width', () {
      expect(CafeCardImage.decodeWidth(const Size(390, 200), 2), 800);
    });

    test('boxes a few pixels apart share one decode size', () {
      expect(
        CafeCardImage.decodeWidth(const Size(160, 100), 3),
        CafeCardImage.decodeWidth(const Size(164, 100), 3),
      );
    });

    test('an unbounded or empty box gives no size to decode at', () {
      expect(
        CafeCardImage.decodeWidth(const Size(double.infinity, 100), 3),
        isNull,
      );
      expect(
        CafeCardImage.decodeWidth(const Size(100, double.infinity), 3),
        isNull,
      );
      expect(CafeCardImage.decodeWidth(Size.zero, 3), isNull);
    });
  });
}
