import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/share_card_footer.dart';

void main() {
  group('ShareCardFooter', () {
    testWidgets('renders wordmark and crawl title',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareCardFooter(crawlTitle: 'Cebu Island · 2026'),
          ),
        ),
      );

      expect(find.text('nook'), findsOneWidget);
      expect(find.text('Cebu Island · 2026'), findsOneWidget);
    });
  });
}
