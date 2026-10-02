import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/use_cases/archive_crawl_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/claim_crawl_stamp_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/create_crawl_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_by_code_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_run_preview_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_run_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/join_crawl_run_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/leave_crawl_run_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/report_crawl_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/start_crawl_run_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/update_crawl_title_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_builder_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_detail_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_run_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/crew_invite_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/edit_crawl_title_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/report_crawl_cubit.dart';
import 'package:nook/features/crawls/presentation/widgets/enter_crawl_code_sheet.dart';

import 'crawl_fixtures.dart';

/// Every request waits on [gate], so a test can act while one is in flight.
class _GatedRepository extends FakeCrawlRepository {
  _GatedRepository({super.currentRun});

  final gate = Completer<void>();
  int createCalls = 0;

  @override
  Future<Crawl> createCrawl({
    required String title,
    String? description,
    required List<String> cafeIds,
    String? sourceListId,
  }) async {
    createCalls++;
    await gate.future;
    return super.createCrawl(
      title: title,
      description: description,
      cafeIds: cafeIds,
      sourceListId: sourceListId,
    );
  }

  @override
  Future<CrawlRun> claimStamp({
    required String runId,
    required String stopId,
    required double lat,
    required double lng,
    double? accuracyMeters,
    String? note,
  }) async {
    await gate.future;
    return super.claimStamp(
      runId: runId,
      stopId: stopId,
      lat: lat,
      lng: lng,
      accuracyMeters: accuracyMeters,
      note: note,
    );
  }

  @override
  Future<Crawl> getCrawlByCode(String shareCode) async {
    await gate.future;
    return super.getCrawlByCode(shareCode);
  }

  @override
  Future<CrawlRun> startRun(String crawlId) async {
    await gate.future;
    return super.startRun(crawlId);
  }

  @override
  Future<Crawl> updateCrawlTitle(String crawlId, String title) async {
    await gate.future;
    return super.updateCrawlTitle(crawlId, title);
  }

  @override
  Future<void> reportCrawl({
    required String crawlId,
    required String reason,
    String? details,
  }) async {
    await gate.future;
    return super.reportCrawl(
      crawlId: crawlId,
      reason: reason,
      details: details,
    );
  }

  @override
  Future<CrawlRunPreview> getRunPreview(String inviteCode) async {
    await gate.future;
    return super.getRunPreview(inviteCode);
  }
}

void main() {
  group('CrawlBuilderCubit while creating (C-4)', () {
    test('a reorder or toggle mid-submit changes nothing and cannot lead to '
        'a second crawl', () async {
      final repo = _GatedRepository();
      final cubit = CrawlBuilderCubit(
        createCrawlUseCase: CreateCrawlUseCase(repo),
        analytics: AnalyticsService(),
        initialCafeIds: ['a', 'b', 'c', 'd'],
      );
      addTearDown(cubit.close);

      final first = cubit.submit(title: 'IT Park Study Crawl');
      await pumpEventQueue();
      expect(cubit.state.status, CrawlBuilderStatus.submitting);

      cubit.reorder(0, 3);
      expect(cubit.toggle('d'), isFalse);
      // Still submitting: the Create button stays off.
      expect(cubit.state.status, CrawlBuilderStatus.submitting);
      expect(cubit.state.selectedIds, ['a', 'b', 'c', 'd']);

      await cubit.submit(title: 'IT Park Study Crawl');
      repo.gate.complete();
      await first;

      expect(repo.createCalls, 1);
      expect(cubit.state.status, CrawlBuilderStatus.created);

      // The created crawl is not put back into editing either.
      cubit.reorder(0, 3);
      await cubit.submit(title: 'IT Park Study Crawl');
      expect(cubit.state.status, CrawlBuilderStatus.created);
      expect(repo.createCalls, 1);
    });
  });

  group('CrawlRunCubit.stampSettled (C-7)', () {
    CrawlRunCubit build(FakeCrawlRepository repo) => CrawlRunCubit(
      getCrawlRunUseCase: GetCrawlRunUseCase(repo),
      claimCrawlStampUseCase: ClaimCrawlStampUseCase(repo),
      leaveCrawlRunUseCase: LeaveCrawlRunUseCase(repo),
      locator: FakeStampLocator(),
      analytics: AnalyticsService(),
    );

    test('resolves at once when no stamp is under way', () async {
      final cubit = build(FakeCrawlRepository(currentRun: run()));
      addTearDown(cubit.close);
      await cubit.load('run-1');

      expect((await cubit.stampSettled()).stampPhase, StampPhase.idle);
    });

    test('waits for the stamp in flight and reports how it ended', () async {
      final repo = _GatedRepository(currentRun: run(stamped: 2));
      final cubit = build(repo);
      addTearDown(cubit.close);
      await cubit.load('run-1');
      final last = cubit.state.run!.crawl.stops.last;

      unawaited(cubit.stamp(last));
      await pumpEventQueue();
      expect(cubit.state.isStamping, isTrue);

      // The sheet is dismissed here; the page waits on the outcome instead.
      var settled = false;
      final outcome = cubit.stampSettled().then((state) {
        settled = true;
        return state;
      });
      await pumpEventQueue();
      expect(settled, isFalse);

      repo.gate.complete();
      final state = await outcome;

      expect(state.stampPhase, StampPhase.stamped);
      // The last stop: the page can still open the recap.
      expect(state.run!.isComplete, isTrue);
    });
  });

  group('per-screen crawl cubits closed mid-request (X-1)', () {
    test('CrawlBuilderCubit', () async {
      final repo = _GatedRepository();
      final cubit = CrawlBuilderCubit(
        createCrawlUseCase: CreateCrawlUseCase(repo),
        analytics: AnalyticsService(),
        initialCafeIds: ['a', 'b', 'c'],
      );
      final pending = cubit.submit(title: 'IT Park Study Crawl');
      await pumpEventQueue();
      await cubit.close();
      repo.gate.complete();

      await expectLater(pending, completes);
    });

    test('CrawlRunCubit', () async {
      final repo = _GatedRepository(currentRun: run());
      final cubit = CrawlRunCubit(
        getCrawlRunUseCase: GetCrawlRunUseCase(repo),
        claimCrawlStampUseCase: ClaimCrawlStampUseCase(repo),
        leaveCrawlRunUseCase: LeaveCrawlRunUseCase(repo),
        locator: FakeStampLocator(),
        analytics: AnalyticsService(),
      );
      await cubit.load('run-1');
      final pending = cubit.stamp(cubit.state.run!.crawl.stops.first);
      await pumpEventQueue();
      await cubit.close();
      repo.gate.complete();

      await expectLater(pending, completes);
    });

    test('CrawlDetailCubit', () async {
      final repo = _GatedRepository(currentRun: run());
      final cubit = CrawlDetailCubit(
        getCrawlByCodeUseCase: GetCrawlByCodeUseCase(repo),
        startCrawlRunUseCase: StartCrawlRunUseCase(repo),
        archiveCrawlUseCase: ArchiveCrawlUseCase(repo),
        analytics: AnalyticsService(),
      );
      final loading = cubit.load('K7M2QX9A', initial: crawl());
      final starting = cubit.startRun();
      await pumpEventQueue();
      await cubit.close();
      repo.gate.complete();

      await expectLater(loading, completes);
      await expectLater(starting, completes);
    });

    test('EditCrawlTitleCubit', () async {
      final repo = _GatedRepository();
      final cubit = EditCrawlTitleCubit(
        updateCrawlTitleUseCase: UpdateCrawlTitleUseCase(repo),
      );
      final pending = cubit.save('crawl-1', 'Lahug Loop');
      await pumpEventQueue();
      await cubit.close();
      repo.gate.complete();

      await expectLater(pending, completes);
    });

    test('ReportCrawlCubit', () async {
      ReportCrawlCubit.resetSession();
      addTearDown(ReportCrawlCubit.resetSession);
      final repo = _GatedRepository();
      final cubit = ReportCrawlCubit(
        reportCrawlUseCase: ReportCrawlUseCase(repo),
      )..choose(ReportCrawlCubit.reasons.first);
      final pending = cubit.submit('crawl-1');
      await pumpEventQueue();
      await cubit.close();
      repo.gate.complete();

      await expectLater(pending, completes);
    });

    test('CrewInviteCubit', () async {
      final repo = _GatedRepository(currentRun: run());
      final cubit = CrewInviteCubit(
        getCrawlRunPreviewUseCase: GetCrawlRunPreviewUseCase(repo),
        getCrawlByCodeUseCase: GetCrawlByCodeUseCase(repo),
        joinCrawlRunUseCase: JoinCrawlRunUseCase(repo),
        analytics: AnalyticsService(),
      );
      final pending = cubit.load('ABCDEF1234');
      await pumpEventQueue();
      await cubit.close();
      repo.gate.complete();

      await expectLater(pending, completes);
    });
  });

  group('ReportCrawlCubit per account (C-8)', () {
    setUp(ReportCrawlCubit.resetSession);
    tearDown(ReportCrawlCubit.resetSession);

    test('"already reported" does not carry over to another account', () async {
      final cubit = ReportCrawlCubit(
        reportCrawlUseCase: ReportCrawlUseCase(FakeCrawlRepository()),
      )..choose(ReportCrawlCubit.reasons.first);
      addTearDown(cubit.close);

      await cubit.submit('crawl-1', reporterId: 'user-a');

      expect(
        ReportCrawlCubit.alreadyReported('crawl-1', reporterId: 'user-a'),
        isTrue,
      );
      expect(
        ReportCrawlCubit.alreadyReported('crawl-1', reporterId: 'user-b'),
        isFalse,
      );
    });
  });

  group('CrawlCodeTarget.parse on a pasted share message (C-8)', () {
    test('the crawl share text gives the crawl code', () {
      final target = CrawlCodeTarget.parse(
        'IT Park Study Crawl, a cafe crawl on Nook\n\n'
        'https://www.nookph.app/c/A1B2C3D4\n\n'
        'Or enter code A1B2C3D4 in the app.',
      );
      expect(target?.code, 'A1B2C3D4');
      expect(target?.isInvite, isFalse);
    });

    test('the crew invite text gives the crew code, not the crawl\'s', () {
      final target = CrawlCodeTarget.parse(
        'Join my crew for IT Park Study Crawl on Nook\n\n'
        'https://www.nookph.app/c/A1B2C3D4?crew=abcdef1234\n\n'
        'Or enter crew code ABCDEF1234 in the app.',
      );
      expect(target?.code, 'ABCDEF1234');
      expect(target?.isInvite, isTrue);
    });

    test('a message with no crawl link is still not a code', () {
      expect(
        CrawlCodeTarget.parse('see https://www.nookph.app/cafes/123 for more'),
        isNull,
      );
      expect(
        CrawlCodeTarget.parse('too long https://www.nookph.app/c/A1B2C3D4E5F6'),
        isNull,
      );
    });
  });

  group('activeRunFor (C-5)', () {
    CrawlRunSummary summary(String id, String code, {DateTime? done}) =>
        CrawlRunSummary(
          runId: id,
          title: 'Crawl',
          shareCode: code,
          stopCount: 3,
          myStamps: 1,
          completedAt: done,
        );

    test('finds the unfinished run of that crawl', () {
      final crawls = MyCrawls(
        runs: [
          summary('r1', 'AAAAAAAA', done: DateTime(2026, 10, 1)),
          summary('r2', 'BBBBBBBB'),
          summary('r3', 'AAAAAAAA'),
        ],
      );

      expect(activeRunFor(crawls, 'AAAAAAAA')?.runId, 'r3');
      expect(activeRunFor(crawls, 'BBBBBBBB')?.runId, 'r2');
    });

    test('a finished run, or none, starts a new one', () {
      final crawls = MyCrawls(
        runs: [summary('r1', 'AAAAAAAA', done: DateTime(2026, 10, 1))],
      );

      expect(activeRunFor(crawls, 'AAAAAAAA'), isNull);
      expect(activeRunFor(crawls, 'CCCCCCCC'), isNull);
      expect(activeRunFor(const MyCrawls(), ''), isNull);
    });
  });
}
