import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';
import 'package:nook/features/crawls/domain/use_cases/create_crawl_usecase.dart';

class UpdateCrawlTitleUseCase {
  final ICrawlRepository repository;

  UpdateCrawlTitleUseCase(this.repository);

  Future<Crawl> call(String crawlId, String title) {
    final trimmed = title.trim();
    if (trimmed.length < CreateCrawlUseCase.minTitleLength ||
        trimmed.length > CreateCrawlUseCase.maxTitleLength) {
      throw ArgumentError(
        'Title must be ${CreateCrawlUseCase.minTitleLength}–'
        '${CreateCrawlUseCase.maxTitleLength} characters.',
      );
    }
    return repository.updateCrawlTitle(crawlId, trimmed);
  }
}
