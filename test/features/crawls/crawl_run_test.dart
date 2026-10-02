import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/use_cases/claim_crawl_stamp_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_run_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/leave_crawl_run_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_run_cubit.dart';

import 'crawl_fixtures.dart';

void main() {
  (CrawlRunCubit, FakeCrawlRepository) build({int stamped = 2}) {
    final repo = FakeCrawlRepository(currentRun: run(stamped: stamped));
    final cubit = CrawlRunCubit(
      getCrawlRunUseCase: GetCrawlRunUseCase(repo),
      claimCrawlStampUseCase: ClaimCrawlStampUseCase(repo),
      leaveCrawlRunUseCase: LeaveCrawlRunUseCase(repo),
      locator: FakeStampLocator(),
      analytics: AnalyticsService(),
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
}
