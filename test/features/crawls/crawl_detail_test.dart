import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/use_cases/archive_crawl_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_by_code_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/report_crawl_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/start_crawl_run_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/update_crawl_title_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_detail_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/edit_crawl_title_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/report_crawl_cubit.dart';

import 'crawl_fixtures.dart';

class _NoAnalytics implements AnalyticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late FakeCrawlRepository repo;

  setUp(() {
    repo = FakeCrawlRepository();
    ReportCrawlCubit.resetSession();
  });

  group('CrawlDetailCubit', () {
    CrawlDetailCubit build() => CrawlDetailCubit(
      getCrawlByCodeUseCase: GetCrawlByCodeUseCase(repo),
      startCrawlRunUseCase: StartCrawlRunUseCase(repo),
      archiveCrawlUseCase: ArchiveCrawlUseCase(repo),
      analytics: _NoAnalytics(),
    );

    test('archive keeps the crawl on screen, marked archived', () async {
      final cubit = build();
      await cubit.load('K7M2QX9A');
      expect(cubit.state.crawl!.isArchived, isFalse);

      await cubit.archive();

      expect(cubit.state.archived, isTrue);
      expect(cubit.state.crawl!.isArchived, isTrue);
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.starting, isFalse);
    });

    test('replaceCrawl swaps the crawl once loaded', () async {
      final cubit = build();
      final renamed = crawl(stops: 4);

      cubit.replaceCrawl(renamed);
      expect(cubit.state.crawl, isNull, reason: 'ignored while loading');

      await cubit.load('K7M2QX9A');
      cubit.replaceCrawl(renamed);
      expect(cubit.state.crawl, renamed);
    });
  });

  group('EditCrawlTitleCubit', () {
    EditCrawlTitleCubit build() => EditCrawlTitleCubit(
      updateCrawlTitleUseCase: UpdateCrawlTitleUseCase(repo),
    );

    test('a short title is refused without calling the server', () async {
      final cubit = build();
      await cubit.save('c1', 'IT');

      expect(cubit.state.problem, EditTitleProblem.length);
      expect(repo.updatedTitle, isNull);
    });

    test('saves the trimmed title', () async {
      final cubit = build();
      await cubit.save('c1', '  IT Park Finals Crawl ');

      expect(repo.updatedTitle, 'IT Park Finals Crawl');
      expect(cubit.state.saved, isNotNull);
      expect(cubit.state.saving, isFalse);
    });

    test('maps server rejections to field problems', () async {
      final cubit = build();

      repo.updateTitleError = const CrawlInvalid('crawl_title_length');
      await cubit.save('c1', 'A fine title');
      expect(cubit.state.problem, EditTitleProblem.length);

      repo.updateTitleError = const CrawlInvalid('crawl_title_rejected');
      await cubit.save('c1', 'A fine title');
      expect(cubit.state.problem, EditTitleProblem.rejected);

      cubit.edited();
      expect(cubit.state.problem, isNull);
    });

    test('other failures surface as an error, not a field problem', () async {
      final cubit = build();
      repo.updateTitleError = Exception('offline');
      await cubit.save('c1', 'A fine title');

      expect(cubit.state.problem, isNull);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.saved, isNull);
    });
  });

  group('ReportCrawlCubit', () {
    ReportCrawlCubit build() =>
        ReportCrawlCubit(reportCrawlUseCase: ReportCrawlUseCase(repo));

    test('cannot submit without a reason', () async {
      final cubit = build();
      expect(cubit.state.canSubmit, isFalse);

      await cubit.submit('c1');
      expect(repo.reportedReason, isNull);
    });

    test(
      'sends the reason, drops blank details, remembers the crawl',
      () async {
        final cubit = build();
        cubit.choose(ReportCrawlCubit.reasons[1]);
        await cubit.submit('c1', details: '   ');

        expect(repo.reportedReason, 'Spam or advertising');
        expect(repo.reportedDetails, isNull);
        expect(cubit.state.sent, isTrue);
        expect(ReportCrawlCubit.alreadyReported('c1'), isTrue);
        expect(ReportCrawlCubit.alreadyReported('c2'), isFalse);
      },
    );

    test('a failed report is not remembered and can be retried', () async {
      final cubit = build();
      cubit.choose(ReportCrawlCubit.reasons.first);
      repo.reportError = Exception('offline');
      await cubit.submit('c1', details: 'Stop 3 closed.');

      expect(cubit.state.sent, isFalse);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.canSubmit, isTrue);
      expect(ReportCrawlCubit.alreadyReported('c1'), isFalse);
    });

    test('every reason fits the server cap', () {
      for (final reason in ReportCrawlCubit.reasons) {
        expect(reason.length, lessThanOrEqualTo(50));
      }
    });
  });
}
