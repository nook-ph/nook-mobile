import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/use_cases/enable_crawl_link_usecase.dart';

import 'crawl_fixtures.dart';

Crawl _crawl({required bool isCreator, required bool isLinkVisible}) => Crawl(
  id: 'crawl-1',
  title: 'IT Park Study Crawl',
  shareCode: 'K7M2QX9A',
  isLinkVisible: isLinkVisible,
  status: 'active',
  isCreator: isCreator,
  stops: const [],
);

void main() {
  group('EnableCrawlLinkUseCase', () {
    late FakeCrawlRepository repository;
    late EnableCrawlLinkUseCase useCase;

    setUp(() {
      repository = FakeCrawlRepository();
      useCase = EnableCrawlLinkUseCase(repository);
    });

    test('opens the creator\'s private crawl before a share', () async {
      await useCase(_crawl(isCreator: true, isLinkVisible: false));
      expect(repository.linkEnabledFor, ['crawl-1']);
    });

    test('leaves a crawl that is already open alone', () async {
      await useCase(_crawl(isCreator: true, isLinkVisible: true));
      expect(repository.linkEnabledFor, isEmpty);
    });

    test('does nothing for someone who is not the creator', () async {
      await useCase(_crawl(isCreator: false, isLinkVisible: false));
      expect(repository.linkEnabledFor, isEmpty);
    });
  });
}
