import 'package:dartz/dartz.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/entities/crawl_detail.dart';
import 'package:nook/features/crawl/domain/repositories/i_crawl_repository.dart';

class GetCrawlDetailUseCase {
  final ICrawlRepository repository;

  GetCrawlDetailUseCase(this.repository);

  Future<Either<Failure, CrawlDetail>> call(String slug) {
    return repository.getCrawlBySlug(slug);
  }
}
