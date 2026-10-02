import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/features/crawls/data/fake_stamp_store.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/use_cases/claim_crawl_stamp_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_run_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/leave_crawl_run_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_run_cubit.dart';

import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/use_cases/get_my_crawls_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/my_crawls_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crawl_fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  (CrawlRunCubit, FakeCrawlRepository) build({
    int stamped = 2,
    bool fakeStamps = false,
  }) {
    final repo = FakeCrawlRepository(currentRun: run(stamped: stamped));
    final cubit = CrawlRunCubit(
      getCrawlRunUseCase: GetCrawlRunUseCase(repo),
      claimCrawlStampUseCase: ClaimCrawlStampUseCase(repo),
      leaveCrawlRunUseCase: LeaveCrawlRunUseCase(repo),
      locator: FakeStampLocator(),
      analytics: AnalyticsService(),
      fakeStampStore: fakeStamps ? FakeStampStore() : null,
    );
    return (cubit, repo);
  }

  group('CrawlRunCubit.leave', () {
    test('leaves the loaded run and reports success', () async {
      final (cubit, repo) = build();
      await cubit.load('run-1');

      expect(await cubit.leave(), isTrue);
      expect(repo.leftRunId, 'run-1');
      expect(cubit.state.isLeaving, isFalse);
    });

    test('a failed leave reports false and keeps the run', () async {
      final (cubit, repo) = build();
      await cubit.load('run-1');
      repo.leaveError = const CrawlNotFound();

      expect(await cubit.leave(), isFalse);
      expect(repo.leftRunId, isNull);
      expect(cubit.state.run, isNotNull);
      expect(cubit.state.status, CrawlRunStatus.loaded);
      expect(cubit.state.isLeaving, isFalse);
    });

    test('does nothing before a run has loaded', () async {
      final (cubit, repo) = build();

      expect(await cubit.leave(), isFalse);
      expect(repo.leftRunId, isNull);
    });
  });

  group('fake stamps (dev aid)', () {
    test(
      'stamp marks the stop on the device and never calls the server',
      () async {
        final (cubit, repo) = build(stamped: 0, fakeStamps: true);
        await cubit.load('run-1');
        final stops = cubit.state.run!.crawl.stops;

        await cubit.stamp(stops.first);

        expect(repo.claimCalls, 0);
        expect(cubit.state.stampPhase, StampPhase.stamped);
        expect(cubit.state.run!.myStampedStopIds, {stops.first.stopId});
        // The server's copy of the run is untouched.
        expect(repo.currentRun!.stamps, isEmpty);
      },
    );

    test('made-up stamps survive a refetch and can finish the crawl', () async {
      final (cubit, _) = build(stamped: 0, fakeStamps: true);
      await cubit.load('run-1');

      for (final stop in cubit.state.run!.crawl.stops) {
        await cubit.stamp(stop);
        cubit.clearStamp();
      }
      await cubit.refresh();

      expect(cubit.state.run!.isComplete, isTrue);
      expect(cubit.state.run!.nextStop, isNull);
    });

    test('made-up stamps are still there on the next visit', () async {
      final (first, _) = build(stamped: 0, fakeStamps: true);
      await first.load('run-1');
      final stops = first.state.run!.crawl.stops;
      await first.stamp(stops.first);
      await first.close();

      final (second, repo) = build(stamped: 0, fakeStamps: true);
      await second.load('run-1');

      expect(second.state.run!.myStampedStopIds, {stops.first.stopId});
      expect(repo.currentRun!.stamps, isEmpty);
    });

    test('leaving the run drops its made-up stamps', () async {
      final (first, _) = build(stamped: 0, fakeStamps: true);
      await first.load('run-1');
      await first.stamp(first.state.run!.crawl.stops.first);
      expect(await first.leave(), isTrue);

      final (second, _) = build(stamped: 0, fakeStamps: true);
      await second.load('run-1');

      expect(second.state.run!.myStampCount, 0);
    });

    test('made-up stamps count toward progress on the Lists tab', () async {
      final store = FakeStampStore();
      final at = DateTime(2026, 10, 3, 15);
      await store.add('run-1', 'stop-1', at);
      await store.add('run-1', 'stop-2', at);
      final repo = FakeCrawlRepository()
        ..myCrawls = const MyCrawls(
          runs: [
            CrawlRunSummary(
              runId: 'run-1',
              title: 'IT Park Study Crawl',
              shareCode: 'K7M2QX9A',
              stopCount: 3,
              myStamps: 0,
            ),
          ],
        );
      final cubit = MyCrawlsCubit(
        getMyCrawlsUseCase: GetMyCrawlsUseCase(repo),
        fakeStampStore: store,
      );

      await cubit.load();
      expect(cubit.state.crawls.runs.single.myStamps, 2);
      expect(cubit.state.crawls.runs.single.isComplete, isFalse);

      await store.add('run-1', 'stop-3', at);
      await cubit.load();
      expect(cubit.state.crawls.runs.single.myStamps, 3);
      expect(cubit.state.crawls.runs.single.isComplete, isTrue);
    });

    test('off by default: a stamp goes to the server', () async {
      final (cubit, repo) = build(stamped: 0);
      await cubit.load('run-1');

      await cubit.stamp(cubit.state.run!.crawl.stops.first);

      expect(repo.claimCalls, 1);
    });
  });
}
