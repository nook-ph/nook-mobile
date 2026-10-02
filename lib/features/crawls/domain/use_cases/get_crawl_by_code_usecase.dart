import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/repositories/i_crawl_repository.dart';

class GetCrawlByCodeUseCase {
  final ICrawlRepository repository;

  GetCrawlByCodeUseCase(this.repository);

  Future<Crawl> call(String shareCode) =>
      repository.getCrawlByCode(shareCode.trim().toUpperCase());
}
