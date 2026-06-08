import 'package:dartz/dartz.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/repositories/i_crawl_repository.dart';

class RegisterForCrawlUseCase {
  final ICrawlRepository repository;

  RegisterForCrawlUseCase(this.repository);

  Future<Either<Failure, Unit>> call(String crawlId) {
    return repository.registerForCrawl(crawlId);
  }
}
