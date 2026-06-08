import 'package:dartz/dartz.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/entities/stamp_claim_result.dart';
import 'package:nook/features/crawl/domain/repositories/i_crawl_repository.dart';

class ClaimStampUseCase {
  final ICrawlRepository repository;

  ClaimStampUseCase(this.repository);

  Future<Either<Failure, StampClaimResult>> call({
    required String crawlId,
    required String stopId,
    required double lat,
    required double lng,
  }) {
    return repository.claimStamp(
      crawlId: crawlId,
      stopId: stopId,
      lat: lat,
      lng: lng,
    );
  }
}
