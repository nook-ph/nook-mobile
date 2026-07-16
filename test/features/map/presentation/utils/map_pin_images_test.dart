import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/map/presentation/utils/map_pin_images.dart';

void main() {
  group('rasterization', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    // PNG magic bytes.
    const pngSignature = [0x89, 0x50, 0x4E, 0x47];

    test('rating pill renders to a non-empty PNG', () async {
      final images = MapPinImages(scale: 3);
      final bytes = await images.rasterizePill('4.5');
      expect(bytes.length, greaterThan(pngSignature.length));
      expect(bytes.sublist(0, 4), pngSignature);
    });

    test('coffee badge renders to a non-empty PNG (exercises the '
        'SVG glyph parser)', () async {
      final images = MapPinImages(scale: 3);
      final bytes = await images.rasterizeCoffeePin();
      expect(bytes.sublist(0, 4), pngSignature);
    });
  });

  group('pillIconFor', () {
    test('is empty for unrated cafes (dot only)', () {
      const cafe = CafeSummary(id: 'a', name: 'A', rating: 0);
      expect(MapPinImages.pillIconFor(cafe), '');
    });

    test('keys the image by one-decimal rating', () {
      const cafe = CafeSummary(
        id: 'a',
        name: 'A',
        rating: 4.5,
        reviewCount: 120,
      );
      expect(MapPinImages.pillIconFor(cafe), 'pill-4.5');
    });

    test('matches pillImageId so layer and image ids agree', () {
      const cafe = CafeSummary(id: 'a', name: 'A', rating: 5, reviewCount: 2);
      expect(
        MapPinImages.pillIconFor(cafe),
        MapPinImages.pillImageId('5.0'),
      );
    });
  });
}
