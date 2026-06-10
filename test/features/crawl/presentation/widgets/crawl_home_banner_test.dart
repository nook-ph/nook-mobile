import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/features/crawl/presentation/cubit/active_crawls_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/active_crawls_state.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_home_banner.dart';

Crawl _fakeCrawl({
  String id = 'crawl-1',
  String city = 'Cebu',
  int totalStops = 12,
  int daysRemaining = 32,
}) {
  return Crawl(
    id: id,
    title: 'Test Crawl $id',
    slug: 'test-crawl-$id',
    startsAt: DateTime(2026, 6, 1),
    endsAt: DateTime.now().add(Duration(days: daysRemaining)),
    status: CrawlStatus.active,
    city: city,
    totalStops: totalStops,
  );
}

Widget _buildTestWidget({
  required ActiveCrawlsCubit cubit,
  Map<String, int>? stampProgress,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider.value(
        value: cubit,
        child: CrawlHomeBanner(stampProgress: stampProgress),
      ),
    ),
  );
}

void main() {
  group('CrawlHomeBanner', () {
    testWidgets('renders Join the Crawl button when unregistered',
        (WidgetTester tester) async {
      final cubit = ActiveCrawlsCubit.forState(
        ActiveCrawlsLoaded([_fakeCrawl()], {}),
      );

      await tester.pumpWidget(_buildTestWidget(cubit: cubit));
      await tester.pump();

      expect(find.text('CEBU ISLAND CRAWL'), findsOneWidget);
      expect(find.text('Collect stamps. Earn badges.'), findsOneWidget);
      expect(find.text('12 stops across Cebu'), findsOneWidget);
      expect(find.textContaining('days left'), findsOneWidget);
      expect(find.text('Join the Crawl'), findsOneWidget);
    });

    testWidgets('renders progress pill when registered',
        (WidgetTester tester) async {
      final cubit = ActiveCrawlsCubit.forState(
        ActiveCrawlsLoaded([_fakeCrawl()], {'crawl-1'}),
      );

      await tester.pumpWidget(
        _buildTestWidget(
          cubit: cubit,
          stampProgress: {'crawl-1': 5},
        ),
      );
      await tester.pump();

      expect(find.text('5 / 12 stamps'), findsOneWidget);
      expect(find.text('Join the Crawl'), findsNothing);
    });

    testWidgets('shows 0 / N stamps when registered without progress',
        (WidgetTester tester) async {
      final cubit = ActiveCrawlsCubit.forState(
        ActiveCrawlsLoaded([_fakeCrawl()], {'crawl-1'}),
      );

      await tester.pumpWidget(
        _buildTestWidget(cubit: cubit, stampProgress: null),
      );
      await tester.pump();

      expect(find.text('0 / 12 stamps'), findsOneWidget);
    });

    testWidgets('renders nothing when state is empty',
        (WidgetTester tester) async {
      final cubit =
          ActiveCrawlsCubit.forState(const ActiveCrawlsEmpty());

      await tester.pumpWidget(_buildTestWidget(cubit: cubit));
      await tester.pump();

      expect(find.byType(CrawlHomeBanner), findsOneWidget);
      expect(find.text('Join the Crawl'), findsNothing);
    });

    testWidgets('renders nothing when state is loading',
        (WidgetTester tester) async {
      final cubit =
          ActiveCrawlsCubit.forState(const ActiveCrawlsLoading());

      await tester.pumpWidget(_buildTestWidget(cubit: cubit));
      await tester.pump();

      expect(find.byType(CrawlHomeBanner), findsOneWidget);
      expect(find.text('Join the Crawl'), findsNothing);
    });

    testWidgets('renders first crawl only when multiple crawls',
        (WidgetTester tester) async {
      final cubit = ActiveCrawlsCubit.forState(
        ActiveCrawlsLoaded(
          [_fakeCrawl(id: 'first', city: 'Manila'), _fakeCrawl(id: 'second')],
          {},
        ),
      );

      await tester.pumpWidget(_buildTestWidget(cubit: cubit));
      await tester.pump();

      expect(find.text('MANILA ISLAND CRAWL'), findsOneWidget);
      expect(find.text('CEBU ISLAND CRAWL'), findsNothing);
    });
  });
}
