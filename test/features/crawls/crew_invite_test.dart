import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_by_code_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_run_preview_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/join_crawl_run_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/crew_invite_cubit.dart';

import 'crawl_fixtures.dart';

void main() {
  group('CrewInviteCubit', () {
    CrewInviteCubit build(FakeCrawlRepository repo) => CrewInviteCubit(
      getCrawlRunPreviewUseCase: GetCrawlRunPreviewUseCase(repo),
      getCrawlByCodeUseCase: GetCrawlByCodeUseCase(repo),
      joinCrawlRunUseCase: JoinCrawlRunUseCase(repo),
      analytics: AnalyticsService(),
    );

    test('loads the preview and the crawl stops behind it', () async {
      final cubit = build(FakeCrawlRepository());
      await cubit.load('ABCDEF1234');

      expect(cubit.state.status, CrewInviteStatus.loaded);
      expect(cubit.state.preview?.title, 'IT Park Study Crawl');
      expect(cubit.state.crawl?.stops, hasLength(3));
      expect(cubit.state.isFull, isFalse);
    });

    test('a missing invite is an error state carrying CrawlNotFound', () async {
      final repo = FakeCrawlRepository()..previewError = const CrawlNotFound();
      final cubit = build(repo);
      await cubit.load('NOPE');

      expect(cubit.state.status, CrewInviteStatus.error);
      expect(cubit.state.error, isA<CrawlNotFound>());
    });

    test('a preview at the crew limit reads as full', () async {
      final repo = FakeCrawlRepository()
        ..preview = const CrawlRunPreview(
          title: 'IT Park Study Crawl',
          shareCode: 'K7M2QX9A',
          stopCount: 5,
          crewSize: 8,
          crewLimit: 8,
        );
      final cubit = build(repo);
      await cubit.load('ABCDEF1234');

      expect(cubit.state.isFull, isTrue);
    });

    test('join hands back the run once, then clears it', () async {
      final repo = FakeCrawlRepository(currentRun: run());
      final cubit = build(repo);
      await cubit.load('ABCDEF1234');
      await cubit.join('ABCDEF1234');

      expect(repo.joinedInviteCode, 'ABCDEF1234');
      expect(cubit.state.joinedRun?.id, 'run-1');
      expect(cubit.state.joining, isFalse);

      cubit.consumeJoinedRun();
      expect(cubit.state.joinedRun, isNull);
    });

    test(
      'a full crew on join turns into the full state, not an error',
      () async {
        final repo = FakeCrawlRepository(currentRun: run())
          ..joinError = const CrewFull();
        final cubit = build(repo);
        await cubit.load('ABCDEF1234');
        await cubit.join('ABCDEF1234');

        expect(cubit.state.isFull, isTrue);
        expect(cubit.state.status, CrewInviteStatus.loaded);
        expect(cubit.state.error, isNull);
        expect(cubit.state.joinedRun, isNull);
      },
    );

    test('a run that vanished before the tap becomes the gone state', () async {
      final repo = FakeCrawlRepository(currentRun: run())
        ..joinError = const CrawlNotFound();
      final cubit = build(repo);
      await cubit.load('ABCDEF1234');
      await cubit.join('ABCDEF1234');

      expect(cubit.state.status, CrewInviteStatus.error);
      expect(cubit.state.error, isA<CrawlNotFound>());
    });

    test('any other join failure keeps the invite on screen', () async {
      final repo = FakeCrawlRepository(currentRun: run())
        ..joinError = Exception('network');
      final cubit = build(repo);
      await cubit.load('ABCDEF1234');
      await cubit.join('ABCDEF1234');

      expect(cubit.state.status, CrewInviteStatus.loaded);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.joining, isFalse);
    });

    test('join does nothing before the preview has loaded', () async {
      final repo = FakeCrawlRepository(currentRun: run());
      final cubit = build(repo);
      await cubit.join('ABCDEF1234');

      expect(repo.joinedInviteCode, isNull);
    });
  });
}
