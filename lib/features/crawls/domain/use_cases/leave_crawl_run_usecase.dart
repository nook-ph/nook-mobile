import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

class LeaveCrawlRunUseCase {
  final ICrawlRepository repository;

  LeaveCrawlRunUseCase(this.repository);

  Future<void> call(String runId) => repository.leaveRun(runId);
}
