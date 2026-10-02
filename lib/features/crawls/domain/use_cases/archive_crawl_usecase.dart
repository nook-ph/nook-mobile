import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

class ArchiveCrawlUseCase {
  final ICrawlRepository repository;

  ArchiveCrawlUseCase(this.repository);

  Future<void> call(String crawlId) => repository.archiveCrawl(crawlId);
}
