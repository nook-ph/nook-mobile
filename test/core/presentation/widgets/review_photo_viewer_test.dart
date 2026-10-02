import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/widgets/review_photo_viewer.dart';
import 'package:nook/utils/theme/theme.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: TAppTheme.lightTheme, home: child);

void main() {
  test('caption detail joins the date and the cafe', () {
    expect(
      reviewPhotoCaptionDetail(date: 'May 23, 2026', cafeName: 'Tadaima'),
      'May 23, 2026 · Tadaima',
    );
    expect(reviewPhotoCaptionDetail(date: 'May 23, 2026'), 'May 23, 2026');
    expect(reviewPhotoCaptionDetail(cafeName: ' Tadaima '), 'Tadaima');
    expect(reviewPhotoCaptionDetail(date: ' ', cafeName: null), isNull);
  });

  testWidgets('a review photo is captioned with who posted it', (tester) async {
    await tester.pumpWidget(
      _host(
        const ReviewPhotoViewer(
          imageUrls: ['https://example.com/a.jpg', 'https://example.com/b.jpg'],
          initialIndex: 0,
          author: 'maria.c',
          captionDetail: 'May 23, 2026 · Tadaima',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('maria.c'), findsOneWidget);
    expect(find.text('May 23, 2026 · Tadaima'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no caption for hero and profile photos', (tester) async {
    await tester.pumpWidget(
      _host(
        const ReviewPhotoViewer(
          imageUrls: ['https://example.com/a.jpg'],
          initialIndex: 0,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('·'), findsNothing);
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
