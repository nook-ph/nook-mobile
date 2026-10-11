import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

String? _assetShown(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  final provider = image.image;
  return provider is AssetImage ? provider.assetName : null;
}

void main() {
  group('CafePhotoPlaceholder.indexFor', () {
    test('is stable for the same name', () {
      expect(
        CafePhotoPlaceholder.indexFor('Kalye Coffee'),
        CafePhotoPlaceholder.indexFor('Kalye Coffee'),
      );
    });

    test('falls back to the first photo without a name', () {
      expect(CafePhotoPlaceholder.indexFor(null), 0);
      expect(CafePhotoPlaceholder.indexFor(''), 0);
    });

    test('spreads names across more than one photo', () {
      final used = {
        for (final name in ['Abaca', 'Bo\'s', 'Commune', 'Dear Joe', 'Elbert'])
          CafePhotoPlaceholder.indexFor(name),
      };
      expect(used.length, greaterThan(1));
    });

    test('matches the webapp hash (lib/utils/photo-placeholder.test.ts)', () {
      // "b" is 98; 98 % 8 == 2. "ab" is 97 * 31 + 98 == 3105; 3105 % 8 == 1.
      expect(CafePhotoPlaceholder.indexFor('b'), 2);
      expect(CafePhotoPlaceholder.indexFor('ab'), 1);
    });
  });

  test('every photo is bundled at both sizes', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final name in CafePhotoPlaceholder.photos) {
      for (final suffix in ['', '_thumb']) {
        final path = 'assets/images/placeholder_cafes/$name$suffix.webp';
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(0), reason: path);
      }
    }
  });

  testWidgets('a card-sized photo says "Sample photo"', (tester) async {
    await tester.pumpWidget(_box(const CafePhotoPlaceholder(seed: 'Abaca')));
    expect(find.text('Sample photo'), findsOneWidget);
    // 200 x 160 at the test view's 3x is 600 px wide: the full-size photo.
    expect(_assetShown(tester), CafePhotoPlaceholder.assetFor('Abaca'));
  });

  testWidgets('a thumbnail shows only the photo, at thumbnail size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _box(const CafePhotoPlaceholder(seed: 'Abaca'), w: 56, h: 56),
    );
    expect(find.text('Sample photo'), findsNothing);
    expect(
      _assetShown(tester),
      CafePhotoPlaceholder.assetFor('Abaca', thumb: true),
    );
  });

  testWidgets(
    'CafeCardImage draws the sample photo for a missing or blank url',
    (tester) async {
      for (final url in [null, '', '   ']) {
        await tester.pumpWidget(
          _box(CafeCardImage(imageUrl: url, placeholderSeed: 'Abaca')),
        );
        expect(
          find.byType(CafePhotoPlaceholder),
          findsOneWidget,
          reason: '$url',
        );
        expect(find.text('Sample photo'), findsOneWidget, reason: '$url');
      }
    },
  );

  testWidgets('CafeCardImage can drop the label', (tester) async {
    await tester.pumpWidget(
      _box(const CafeCardImage(imageUrl: null, showSampleLabel: false)),
    );
    expect(find.byType(CafePhotoPlaceholder), findsOneWidget);
    expect(find.text('Sample photo'), findsNothing);
  });
}
