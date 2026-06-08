import 'package:dartz/dartz.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/features/crawl/domain/entities/crawl_detail.dart';
import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';
import 'package:nook/features/crawl/domain/entities/stamp_claim_result.dart';

abstract class ICrawlRepository {
  Future<Either<Failure, List<Crawl>>> getActiveCrawls();

  Future<Either<Failure, CrawlDetail>> getCrawlBySlug(String slug);

  Future<Either<Failure, Unit>> registerForCrawl(String crawlId);

  Future<Either<Failure, StampClaimResult>> claimStamp({
    required String crawlId,
    required String stopId,
    required double lat,
    required double lng,
  });

  Future<Either<Failure, CrawlShareCardData>> getShareCardData(String crawlId);
}
