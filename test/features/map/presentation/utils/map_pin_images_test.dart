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

    test('selected unrated badge and place pin render to PNGs', () async {
      final images = MapPinImages(scale: 3);
      expect(
        (await images.rasterizeSelectedCoffeePin()).sublist(0, 4),
        pngSignature,
      );
      expect((await images.rasterizePlacePin()).sublist(0, 4), pngSignature);
    });

    test('selected unrated badge is a 38pt circle plus shadow room', () async {
      final bytes = await MapPinImages(scale: 2).rasterizeSelectedCoffeePin();
      // PNG IHDR: width and height are big-endian ints at bytes 16 and 20.
      int at(int i) =>
          bytes[i] << 24 |
          bytes[i + 1] << 16 |
          bytes[i + 2] << 8 |
          bytes[i + 3];
      // (38 + 2 x 8 shadow padding) x scale, square so it centres on the cafe.
      expect(at(16), 108);
      expect(at(20), 108);
    });
  });

  test('map-only images have their own ids', () {
    expect(
      MapPinImages.selectedCoffeeImageId,
      isNot(MapPinImages.coffeeImageId),
    );
    expect(MapPinImages.placePinImageId, 'origin-pin');
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
      expect(MapPinImages.pillIconFor(cafe), MapPinImages.pillImageId('5.0'));
    });
  });
}
