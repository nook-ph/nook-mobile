import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/use_cases/claim_crawl_stamp_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/create_crawl_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_run_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/leave_crawl_run_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_builder_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_run_cubit.dart';

import 'crawl_fixtures.dart';

void main() {
  group('CrawlBuilderCubit', () {
    CrawlBuilderCubit build(FakeCrawlRepository repo, List<String> ids) =>
        CrawlBuilderCubit(
          createCrawlUseCase: CreateCrawlUseCase(repo),
          analytics: AnalyticsService(),
          initialCafeIds: ids,
        );

    test('starts with at most six stops picked, in list order', () {
      final cubit = build(FakeCrawlRepository(), [
        for (var i = 1; i <= 8; i++) 'c$i',
      ]);
      expect(cubit.state.selectedIds, ['c1', 'c2', 'c3', 'c4', 'c5', 'c6']);
      expect(cubit.state.isFull, isTrue);
    });

    test('refuses a seventh stop, and unpicking frees the slot', () {
      final cubit = build(FakeCrawlRepository(), [
        for (var i = 1; i <= 7; i++) 'c$i',
      ]);
      expect(cubit.toggle('c7'), isFalse);
      expect(cubit.state.selectedIds, hasLength(6));

      expect(cubit.toggle('c2'), isTrue);
      expect(cubit.toggle('c7'), isTrue);
      expect(cubit.state.selectedIds.last, 'c7');
      expect(cubit.state.orderOf('c7'), 6);
      expect(cubit.state.orderOf('c2'), isNull);
    });

    test('reorder follows ReorderableListView index semantics', () {
      final cubit = build(FakeCrawlRepository(), ['a', 'b', 'c', 'd']);
      cubit.reorder(0, 3); // drag a down to sit before d
      expect(cubit.state.selectedIds, ['b', 'c', 'a', 'd']);
      cubit.reorder(3, 0); // drag d to the top
      expect(cubit.state.selectedIds, ['d', 'b', 'c', 'a']);
    });

    test('needs three stops', () {
      final cubit = build(FakeCrawlRepository(), ['a', 'b']);
      expect(cubit.state.hasEnoughStops, isFalse);
    });

    test('submit sends the trimmed title and the stops in order', () async {
      final repo = FakeCrawlRepository();
      final cubit = build(repo, ['a', 'b', 'c']);
      cubit.reorder(2, 0);

      await cubit.submit(title: '  Study Crawl ', sourceListId: 'list-1');

      expect(repo.createdTitle, 'Study Crawl');
      expect(repo.createdCafeIds, ['c', 'a', 'b']);
      expect(cubit.state.status, CrawlBuilderStatus.created);
      expect(cubit.state.created, isNotNull);
    });

    test('a server rejection lands as failed, keeping the selection', () async {
      final repo = FakeCrawlRepository()
        ..createError = const CrawlInvalid('crawl_unknown_cafe');
      final cubit = build(repo, ['a', 'b', 'c']);

      await cubit.submit(title: 'Study Crawl');

      expect(cubit.state.status, CrawlBuilderStatus.failed);
      expect(cubit.state.error, isA<CrawlInvalid>());
      expect(cubit.state.selectedIds, ['a', 'b', 'c']);
    });
  });

  group('CrawlRunCubit', () {
    (CrawlRunCubit, FakeCrawlRepository, FakeStampLocator) build({
      int stamped = 0,
    }) {
      final repo = FakeCrawlRepository(currentRun: run(stamped: stamped));
      final locator = FakeStampLocator();
      final cubit = CrawlRunCubit(
        getCrawlRunUseCase: GetCrawlRunUseCase(repo),
        claimCrawlStampUseCase: ClaimCrawlStampUseCase(repo),
        leaveCrawlRunUseCase: LeaveCrawlRunUseCase(repo),
        locator: locator,
        analytics: AnalyticsService(),
      );
      return (cubit, repo, locator);
    }

    test('a successful stamp updates the run and reports stamped', () async {
      final (cubit, repo, _) = build();
      await cubit.load('run-1');
      final stop = cubit.state.run!.crawl.stops.first;

      await cubit.stamp(stop);

      expect(cubit.state.stampPhase, StampPhase.stamped);
      expect(cubit.state.stampStop, stop);
      expect(cubit.state.run!.myStampedStopIds, {'stop-1'});
      expect(repo.claimCalls, 1);
    });

    test('too far surfaces the measured distance and awards nothing', () async {
      final (cubit, repo, _) = build();
      repo.claimError = const StampTooFar(180);
      await cubit.load('run-1');

      await cubit.stamp(cubit.state.run!.crawl.stops.first);

      expect(cubit.state.stampPhase, StampPhase.failed);
      expect((cubit.state.stampError! as StampTooFar).distanceMeters, 180);
      expect(cubit.state.run!.myStampCount, 0);
    });

    test('without a location fix the server is never asked', () async {
      final (cubit, repo, locator) = build();
      locator.error = const StampLocationUnavailable(LocationProblem.denied);
      await cubit.load('run-1');

      await cubit.stamp(cubit.state.run!.crawl.stops.first);

      expect(cubit.state.stampPhase, StampPhase.failed);
      expect(cubit.state.stampError, isA<StampLocationUnavailable>());
      expect(repo.claimCalls, 0);
    });

    test('retrying after a failure can succeed', () async {
      final (cubit, repo, _) = build();
      repo.claimError = const StampLowAccuracy(400);
      await cubit.load('run-1');
      final stop = cubit.state.run!.crawl.stops.first;

      await cubit.stamp(stop);
      expect(cubit.state.stampPhase, StampPhase.failed);

      repo.claimError = null;
      await cubit.stamp(stop);
      expect(cubit.state.stampPhase, StampPhase.stamped);
      expect(cubit.state.stampError, isNull);
    });

    test('the last stamp completes the run', () async {
      final (cubit, _, _) = build(stamped: 2);
      await cubit.load('run-1');

      await cubit.stamp(cubit.state.run!.crawl.stops.last);

      expect(cubit.state.run!.isComplete, isTrue);
    });

    test('a failed refresh keeps the run that is on screen', () async {
      final (cubit, repo, _) = build(stamped: 1);
      await cubit.load('run-1');
      repo.getRunError = Exception('offline');

      await cubit.refresh();

      expect(cubit.state.status, CrawlRunStatus.loaded);
      expect(cubit.state.run!.myStampCount, 1);
    });

    test('clearStamp returns to idle', () async {
      final (cubit, _, _) = build();
      await cubit.load('run-1');
      await cubit.stamp(cubit.state.run!.crawl.stops.first);

      cubit.clearStamp();

      expect(cubit.state.stampPhase, StampPhase.idle);
    });
  });
}
