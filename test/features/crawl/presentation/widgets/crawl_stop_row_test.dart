import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stop.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_stop_row.dart';

Widget _buildTestWidget({
  required CrawlStop stop,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: CrawlStopRow(
          stop: stop,
        ),
      ),
    ),
  );
}

CrawlStop _claimedStop({
  int order = 1,
  String name = 'Cafe One',
  String address = '123 Main St',
  DateTime? claimedAt,
}) {
  return CrawlStop(
    id: 'stop-$order',
    crawlId: 'crawl-1',
    cafeId: 'cafe-$order',
    cafeName: name,
    cafeAddress: address,
    cafeLat: 10.0,
    cafeLng: 123.0,
    stopOrder: order,
    tier: 'city',
    isClaimed: true,
    claimedAt: claimedAt ?? DateTime(2026, 6, 10),
  );
}

CrawlStop _unclaimedStop({
  int order = 2,
  String name = 'Cafe Two',
  String address = '456 Oak Ave',
}) {
  return CrawlStop(
    id: 'stop-$order',
    crawlId: 'crawl-1',
    cafeId: 'cafe-$order',
    cafeName: name,
    cafeAddress: address,
    cafeLat: 10.0,
    cafeLng: 123.0,
    stopOrder: order,
    tier: 'city',
    isClaimed: false,
    claimedAt: null,
  );
}

void main() {
  group('CrawlStopRow', () {
    testWidgets('renders claimed stop with checkmark and tinted background',
        (WidgetTester tester) async {
      final stop = _claimedStop();
      await tester.pumpWidget(_buildTestWidget(stop: stop));

      expect(find.text('01'), findsOneWidget);
      expect(find.text('Cafe One'), findsOneWidget);
      expect(find.text('123 Main St'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('renders unclaimed stop without checkmark and with white background',
        (WidgetTester tester) async {
      final stop = _unclaimedStop();
      await tester.pumpWidget(_buildTestWidget(stop: stop));

      expect(find.text('02'), findsOneWidget);
      expect(find.text('Cafe Two'), findsOneWidget);
      expect(find.text('456 Oak Ave'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('handles stop with null claimedAt when isClaimed is true',
        (WidgetTester tester) async {
      final stop = _claimedStop(claimedAt: null);
      await tester.pumpWidget(_buildTestWidget(stop: stop));

      expect(find.text('01'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles stop with null claimedAt when isClaimed is false',
        (WidgetTester tester) async {
      final stop = CrawlStop(
        id: 'stop-3',
        crawlId: 'crawl-1',
        cafeId: 'cafe-3',
        cafeName: 'Cafe Three',
        cafeAddress: '789 Pine Rd',
        cafeLat: 10.0,
        cafeLng: 123.0,
        stopOrder: 3,
        tier: 'city',
        isClaimed: false,
        claimedAt: null,
      );
      await tester.pumpWidget(_buildTestWidget(stop: stop));

      expect(find.text('03'), findsOneWidget);
      expect(find.text('Cafe Three'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow on narrow screen',
        (WidgetTester tester) async {
      final stop = _claimedStop(
        name: 'A Very Long Cafe Name That Should Still Fit',
        address: '123 Very Long Street Address That Might Wrap Around',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: CrawlStopRow(stop: stop),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
