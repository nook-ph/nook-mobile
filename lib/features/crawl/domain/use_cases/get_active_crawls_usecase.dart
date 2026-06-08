import 'package:dartz/dartz.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/features/crawl/domain/repositories/i_crawl_repository.dart';

class GetActiveCrawlsUseCase {
  final ICrawlRepository repository;

  GetActiveCrawlsUseCase(this.repository);

  Future<Either<Failure, List<Crawl>>> call() {
    return repository.getActiveCrawls();
  }
}
