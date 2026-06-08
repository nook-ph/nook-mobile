import 'package:dartz/dartz.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';
import 'package:nook/features/crawl/domain/repositories/i_crawl_repository.dart';

class GetShareCardDataUseCase {
  final ICrawlRepository repository;

  GetShareCardDataUseCase(this.repository);

  Future<Either<Failure, CrawlShareCardData>> call(String crawlId) {
    return repository.getShareCardData(crawlId);
  }
}
