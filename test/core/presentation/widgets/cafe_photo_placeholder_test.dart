import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/presentation/widgets/cafe_photo_placeholder.dart';

Widget _box(Widget child, {double w = 200, double h = 160}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: w, height: h, child: child),
    ),
  ),
);

void main() {
  group('CafePhotoPlaceholder.tintFor', () {
    test('is stable for the same name', () {
      expect(
        CafePhotoPlaceholder.tintFor('Kalye Coffee'),
        same(CafePhotoPlaceholder.tintFor('Kalye Coffee')),
      );
    });

    test('falls back to the first tint without a name', () {
      expect(
        CafePhotoPlaceholder.tintFor(null),
        same(CafePhotoPlaceholder.tints.first),
      );
      expect(
        CafePhotoPlaceholder.tintFor(''),
        same(CafePhotoPlaceholder.tints.first),
      );
    });

    test('spreads names across more than one tint', () {
      final used = {
        for (final name in ['Abaca', 'Bo\'s', 'Commune', 'Dear Joe', 'Elbert'])
          CafePhotoPlaceholder.tintFor(name),
      };
      expect(used.length, greaterThan(1));
    });
  });

  testWidgets('a card-sized tile says "No photo yet"', (tester) async {
    await tester.pumpWidget(_box(const CafePhotoPlaceholder(seed: 'Abaca')));
    expect(find.text('No photo yet'), findsOneWidget);
  });

  testWidgets('a thumbnail shows only the cup', (tester) async {
    await tester.pumpWidget(
      _box(const CafePhotoPlaceholder(seed: 'Abaca'), w: 56, h: 56),
    );
    expect(find.text('No photo yet'), findsNothing);
  });

  testWidgets('CafeCardImage draws the tile for a missing or blank url', (
    tester,
  ) async {
    for (final url in [null, '', '   ']) {
      await tester.pumpWidget(
        _box(CafeCardImage(imageUrl: url, placeholderSeed: 'Abaca')),
      );
      expect(find.byType(CafePhotoPlaceholder), findsOneWidget, reason: '$url');
    }
  });

  testWidgets('CafeCardImage can drop the caption', (tester) async {
    await tester.pumpWidget(
      _box(const CafeCardImage(imageUrl: null, showNoPhotoCaption: false)),
    );
    expect(find.byType(CafePhotoPlaceholder), findsOneWidget);
    expect(find.text('No photo yet'), findsNothing);
  });
}
