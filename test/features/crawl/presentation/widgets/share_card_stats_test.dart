import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';
import 'package:nook/features/crawl/domain/entities/crawl_tier.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/share_card_stats.dart';

void main() {
  group('ShareCardStats', () {
    testWidgets('renders in-progress state (no highestTier)',
        (WidgetTester tester) async {
      final data = CrawlShareCardData(
        userName: 'TestUser',
        crawlTitle: 'Cebu Island',
        crawlPeriod: 'Jun 01 - Jun 30, 2026',
        totalStamps: 3,
        totalStops: 12,
        highestTier: null,
        stops: [
          const CrawlStopShareItem(
            stopOrder: 1,
            tier: 'city',
            cafeName: 'Cafe Brindle',
            isClaimed: true,
            claimedAt: null,
          ),
          const CrawlStopShareItem(
            stopOrder: 2,
            tier: 'city',
            cafeName: 'The Good Cup',
            isClaimed: true,
            claimedAt: null,
          ),
          const CrawlStopShareItem(
            stopOrder: 3,
            tier: 'city',
            cafeName: 'Tightrope Coffee',
            isClaimed: true,
            claimedAt: null,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareCardStats(data: data),
          ),
        ),
      );

      expect(find.text('STOPS'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('LATEST'), findsOneWidget);
      expect(find.text('CRAWL'), findsOneWidget);
      expect(find.text('Cebu Island · Jun 01 - Jun 30, 2026'), findsOneWidget);
    });

    testWidgets('renders completed state (with highestTier)',
        (WidgetTester tester) async {
      final tier = CrawlTier(
        id: 'tier-1',
        crawlId: 'crawl-1',
        slug: 'city-explorer',
        name: 'City Explorer',
        tierOrder: 1,
        totalRequired: 8,
        totalClaimed: 8,
        isComplete: true,
      );

      final data = CrawlShareCardData(
        userName: 'TestUser',
        crawlTitle: 'Cebu Island',
        crawlPeriod: 'Jun 01 - Jun 30, 2026',
        totalStamps: 8,
        totalStops: 12,
        highestTier: tier,
        stops: [
          const CrawlStopShareItem(
            stopOrder: 1,
            tier: 'city',
            cafeName: 'Cafe Brindle',
            isClaimed: true,
          ),
          const CrawlStopShareItem(
            stopOrder: 2,
            tier: 'city',
            cafeName: 'The Good Cup',
            isClaimed: true,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareCardStats(data: data),
          ),
        ),
      );

      expect(find.text('STOPS'), findsOneWidget);
      expect(find.text('8 of 12'), findsOneWidget);
      expect(find.text('TIER'), findsOneWidget);
      expect(find.text('City Explorer'), findsOneWidget);
      expect(find.text('CRAWL'), findsOneWidget);
      expect(find.text('Cebu Island · Jun 01 - Jun 30, 2026'), findsOneWidget);
    });

    testWidgets('shows em dash when no claimed stops',
        (WidgetTester tester) async {
      final data = CrawlShareCardData(
        userName: 'TestUser',
        crawlTitle: 'Cebu Island',
        crawlPeriod: 'Jun 01 - Jun 30, 2026',
        totalStamps: 0,
        totalStops: 12,
        highestTier: null,
        stops: [
          const CrawlStopShareItem(
            stopOrder: 1,
            tier: 'city',
            cafeName: 'Cafe Brindle',
            isClaimed: false,
          ),
          const CrawlStopShareItem(
            stopOrder: 2,
            tier: 'city',
            cafeName: 'The Good Cup',
            isClaimed: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareCardStats(data: data),
          ),
        ),
      );

      expect(find.text('\u2014'), findsOneWidget);
    });
  });
}
