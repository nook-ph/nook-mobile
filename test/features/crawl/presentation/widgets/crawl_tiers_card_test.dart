import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/crawl/domain/entities/crawl_tier.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_tiers_card.dart';

Widget _buildTestWidget(List<CrawlTier> tiers) {
  return MaterialApp(
    home: Scaffold(
      body: CrawlTiersCard(tiers: tiers),
    ),
  );
}

CrawlTier _completedTier({
  String name = 'Explorer',
  int total = 5,
}) {
  return CrawlTier(
    id: 'tier-1',
    crawlId: 'crawl-1',
    slug: 'explorer',
    name: name,
    tierOrder: 1,
    totalRequired: total,
    totalClaimed: total,
    isComplete: true,
  );
}

CrawlTier _activeTier({
  String name = 'Adventurer',
  int claimed = 4,
  int total = 10,
}) {
  return CrawlTier(
    id: 'tier-2',
    crawlId: 'crawl-1',
    slug: 'adventurer',
    name: name,
    tierOrder: 2,
    totalRequired: total,
    totalClaimed: claimed,
    isComplete: false,
  );
}

CrawlTier _lockedTier({
  String name = 'Trailblazer',
  int total = 15,
}) {
  return CrawlTier(
    id: 'tier-3',
    crawlId: 'crawl-1',
    slug: 'trailblazer',
    name: name,
    tierOrder: 3,
    totalRequired: total,
    totalClaimed: 0,
    isComplete: false,
  );
}

void main() {
  group('CrawlTiersCard', () {
    testWidgets('renders label, counter, and all three tier names',
        (WidgetTester tester) async {
      final tiers = [
        _completedTier(),
        _activeTier(),
        _lockedTier(),
      ];

      await tester.pumpWidget(_buildTestWidget(tiers));

      expect(find.text('Milestones'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('Adventurer'), findsOneWidget);
      expect(find.text('Trailblazer'), findsOneWidget);
    });

    testWidgets('completed tier shows checkmark, N/N text, and progress ring',
        (WidgetTester tester) async {
      final tiers = [
        _completedTier(total: 5),
        _activeTier(),
        _lockedTier(),
      ];

      await tester.pumpWidget(_buildTestWidget(tiers));

      expect(find.text('5/5'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('active tier shows map pin and X/Y',
        (WidgetTester tester) async {
      final tiers = [
        _completedTier(),
        _activeTier(claimed: 4, total: 10),
        _lockedTier(),
      ];

      await tester.pumpWidget(_buildTestWidget(tiers));

      expect(find.text('4/10'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets('locked tier shows lock and 0/Y',
        (WidgetTester tester) async {
      final tiers = [
        _completedTier(),
        _activeTier(),
        _lockedTier(total: 15),
      ];

      await tester.pumpWidget(_buildTestWidget(tiers));

      expect(find.text('0/15'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('renders without overflow on narrow screen',
        (WidgetTester tester) async {
      final tiers = [
        _completedTier(name: 'Explorer', total: 5),
        _activeTier(name: 'Adventurer', claimed: 4, total: 10),
        _lockedTier(name: 'Trailblazer', total: 15),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: CrawlTiersCard(tiers: tiers),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
