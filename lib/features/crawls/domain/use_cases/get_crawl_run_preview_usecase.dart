import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

class GetCrawlRunPreviewUseCase {
  final ICrawlRepository repository;

  GetCrawlRunPreviewUseCase(this.repository);

  Future<CrawlRunPreview> call(String inviteCode) =>
      repository.getRunPreview(inviteCode);
}
