import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/use_cases/claim_crawl_stamp_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_run_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/leave_crawl_run_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_run_cubit.dart';

import 'crawl_fixtures.dart';

void main() {
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
      fakeStamps: fakeStamps,
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

    test('off by default: a stamp goes to the server', () async {
      final (cubit, repo) = build(stamped: 0);
      await cubit.load('run-1');

      await cubit.stamp(cubit.state.run!.crawl.stops.first);

      expect(repo.claimCalls, 1);
    });
  });
}
