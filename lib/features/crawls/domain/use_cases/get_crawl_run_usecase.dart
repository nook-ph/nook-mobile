import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

class GetCrawlRunUseCase {
  final ICrawlRepository repository;

  GetCrawlRunUseCase(this.repository);

  Future<CrawlRun> call(String runId) => repository.getRun(runId);
}
