import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

class JoinCrawlRunUseCase {
  final ICrawlRepository repository;

  JoinCrawlRunUseCase(this.repository);

  Future<CrawlRun> call(String inviteCode) => repository.joinRun(inviteCode);
}
