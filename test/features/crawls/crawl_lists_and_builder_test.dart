import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/use_cases/create_crawl_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_my_crawls_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_builder_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/my_crawls_cubit.dart';
import 'package:nook/features/crawls/presentation/widgets/enter_crawl_code_sheet.dart';

import 'crawl_fixtures.dart';

class _MyCrawlsRepository extends FakeCrawlRepository {
  Object? error;
  MyCrawls result = const MyCrawls();

  @override
  Future<MyCrawls> getMyCrawls() async {
    final e = error;
    if (e != null) throw e;
    return result;
  }
}

void main() {
  group('CrawlCodeTarget.parse', () {
    test('an 8-character code is a crawl, in any case and spacing', () {
      final target = CrawlCodeTarget.parse('  a7c2 0f9a ');
      expect(target?.code, 'A7C20F9A');
      expect(target?.isInvite, isFalse);
    });

    test('a 10-character code is a crew invite', () {
      final target = CrawlCodeTarget.parse('abcdef1234');
      expect(target?.code, 'ABCDEF1234');
      expect(target?.isInvite, isTrue);
    });

    test('a pasted crawl link gives the code after /c/', () {
      for (final link in [
        'https://www.nookph.app/c/A1B2C3D4',
        'nookph.app/c/a1b2c3d4',
        'https://www.nookph.app/c/A1B2C3D4/',
      ]) {
        final target = CrawlCodeTarget.parse(link);
        expect(target?.code, 'A1B2C3D4', reason: link);
        expect(target?.isInvite, isFalse, reason: link);
      }
    });

    test('a link with a crew parameter is an invite', () {
      final target = CrawlCodeTarget.parse(
        'https://www.nookph.app/c/A1B2C3D4?crew=abcdef1234',
      );
      expect(target?.code, 'ABCDEF1234');
      expect(target?.isInvite, isTrue);
    });

    test('anything else is not a code', () {
      for (final input in [
        '',
        '   ',
        'A1B2C3', // too short
        'A1B2C3D4E', // nine
        'ZZZZZZZZ', // not hex
        'https://www.nookph.app/cafes/123',
        'https://www.nookph.app/',
      ]) {
        expect(CrawlCodeTarget.parse(input), isNull, reason: input);
      }
    });
  });

  group('MyCrawlsCubit', () {
    test('goes from initial through loading to loaded', () async {
      final repo = _MyCrawlsRepository()..result = MyCrawls(created: [crawl()]);
      final cubit = MyCrawlsCubit(getMyCrawlsUseCase: GetMyCrawlsUseCase(repo));
      final states = <MyCrawlsStatus>[];
      final sub = cubit.stream.listen((s) => states.add(s.status));

      await cubit.load();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states, [MyCrawlsStatus.loading, MyCrawlsStatus.loaded]);
      expect(cubit.state.crawls.created, hasLength(1));
    });

    test('a failed first load is an error with nothing to show', () async {
      final repo = _MyCrawlsRepository()..error = Exception('offline');
      final cubit = MyCrawlsCubit(getMyCrawlsUseCase: GetMyCrawlsUseCase(repo));

      await cubit.load();

      expect(cubit.state.status, MyCrawlsStatus.error);
      expect(cubit.state.crawls.isEmpty, isTrue);
    });

    test('a failed reload keeps what was already loaded, and retry '
        'recovers', () async {
      final repo = _MyCrawlsRepository()..result = MyCrawls(created: [crawl()]);
      final cubit = MyCrawlsCubit(getMyCrawlsUseCase: GetMyCrawlsUseCase(repo));
      await cubit.load();

      repo.error = Exception('offline');
      await cubit.load();
      expect(cubit.state.status, MyCrawlsStatus.error);
      expect(cubit.state.crawls.created, hasLength(1));

      repo.error = null;
      await cubit.load();
      expect(cubit.state.status, MyCrawlsStatus.loaded);
    });

    test('reset drops everything', () async {
      final repo = _MyCrawlsRepository()..result = MyCrawls(created: [crawl()]);
      final cubit = MyCrawlsCubit(getMyCrawlsUseCase: GetMyCrawlsUseCase(repo));
      await cubit.load();
      cubit.reset();
      expect(cubit.state, const MyCrawlsState());
    });
  });

  group('CrawlBuilderCubit title and failures', () {
    CrawlBuilderCubit build(FakeCrawlRepository repo, List<String> ids) =>
        CrawlBuilderCubit(
          createCrawlUseCase: CreateCrawlUseCase(repo),
          analytics: AnalyticsService(),
          initialCafeIds: ids,
        );

    test('checkTitle enforces 3 to 60 characters after trimming', () {
      expect(CrawlBuilderCubit.checkTitle('  xx  '), CrawlTitleProblem.length);
      expect(CrawlBuilderCubit.checkTitle('x' * 61), CrawlTitleProblem.length);
      expect(CrawlBuilderCubit.checkTitle('IT Park Study Crawl'), isNull);
      expect(CrawlBuilderCubit.checkTitle('x' * 60), isNull);
    });

    test('a rate limit fails the crawl, not the title, and keeps the '
        'stops', () async {
      final repo = FakeCrawlRepository()
        ..createError = const CrawlRateLimited();
      final cubit = build(repo, ['a', 'b', 'c', 'd']);

      await cubit.submit(title: 'IT Park Study Crawl');

      expect(cubit.state.status, CrawlBuilderStatus.failed);
      expect(cubit.state.titleRefused, isFalse);
      expect(cubit.state.selectedIds, ['a', 'b', 'c', 'd']);
    });

    test('a server title refusal is flagged for the field', () async {
      final repo = FakeCrawlRepository()
        ..createError = const CrawlInvalid('crawl_title_length');
      final cubit = build(repo, ['a', 'b', 'c']);

      await cubit.submit(title: 'IT Park Study Crawl');

      expect(cubit.state.titleRefused, isTrue);
    });

    test('an unknown cafe is not a title problem', () async {
      final repo = FakeCrawlRepository()
        ..createError = const CrawlInvalid('crawl_unknown_cafe');
      final cubit = build(repo, ['a', 'b', 'c']);

      await cubit.submit(title: 'IT Park Study Crawl');

      expect(cubit.state.status, CrawlBuilderStatus.failed);
      expect(cubit.state.titleRefused, isFalse);
    });

    test('dismissFailure clears the error and keeps the selection; retry '
        'then succeeds', () async {
      final repo = FakeCrawlRepository()..createError = Exception('offline');
      final cubit = build(repo, ['a', 'b', 'c']);
      await cubit.submit(title: 'IT Park Study Crawl');

      cubit.dismissFailure();
      expect(cubit.state.status, CrawlBuilderStatus.editing);
      expect(cubit.state.error, isNull);
      expect(cubit.state.selectedIds, ['a', 'b', 'c']);

      repo.createError = null;
      await cubit.submit(title: 'IT Park Study Crawl');
      expect(cubit.state.status, CrawlBuilderStatus.created);
      expect(cubit.state.created, isA<Crawl>());
    });

    test('dismissFailure does nothing while editing', () {
      final cubit = build(FakeCrawlRepository(), ['a', 'b', 'c']);
      final before = cubit.state;
      cubit.dismissFailure();
      expect(cubit.state, before);
    });
  });
}
