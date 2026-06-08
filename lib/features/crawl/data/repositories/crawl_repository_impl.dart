import 'package:dartz/dartz.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/data/sources/crawl_remote_data_source.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/features/crawl/domain/entities/crawl_detail.dart';
import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';
import 'package:nook/features/crawl/domain/entities/stamp_claim_result.dart';
import 'package:nook/features/crawl/domain/failures/crawl_failures.dart';
import 'package:nook/features/crawl/domain/repositories/i_crawl_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CrawlRepositoryImpl implements ICrawlRepository {
  final ICrawlRemoteDataSource remoteDataSource;
  final SupabaseClient supabase;

  CrawlRepositoryImpl(this.remoteDataSource, this.supabase);

  @override
  Future<Either<Failure, List<Crawl>>> getActiveCrawls() async {
    try {
      final models = await remoteDataSource.getActiveCrawls();
      return Right(models);
    } catch (e, st) {
      return Left(_mapToFailure(e, st));
    }
  }

  @override
  Future<Either<Failure, CrawlDetail>> getCrawlBySlug(String slug) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      final model = await remoteDataSource.getCrawlBySlug(slug, userId);
      return Right(model);
    } catch (e, st) {
      if (e is CrawlNotFoundException) {
        return Left(CrawlNotFoundFailure());
      }
      return Left(_mapToFailure(e, st));
    }
  }

  @override
  Future<Either<Failure, Unit>> registerForCrawl(String crawlId) async {
    try {
      await remoteDataSource.registerForCrawl(crawlId);
      return const Right(unit);
    } catch (e, st) {
      if (e is AlreadyRegisteredException) {
        return Left(AlreadyRegisteredFailure());
      }
      return Left(_mapToFailure(e, st));
    }
  }

  @override
  Future<Either<Failure, StampClaimResult>> claimStamp({
    required String crawlId,
    required String stopId,
    required double lat,
    required double lng,
  }) async {
    try {
      final result = await remoteDataSource.claimStamp(
        crawlId: crawlId,
        stopId: stopId,
        lat: lat,
        lng: lng,
      );
      return Right(result);
    } on LocationTooFarException catch (e) {
      return Left(LocationTooFarFailure(e.distanceMeters));
    } on AlreadyClaimedException catch (e) {
      return Left(
        AlreadyClaimedFailure(
          e.claimedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    } on CrawlEndedException {
      return Left(CrawlEndedFailure());
    } on StopInactiveException {
      return Left(StopInactiveFailure());
    } catch (e, st) {
      return Left(_mapToFailure(e, st));
    }
  }

  @override
  Future<Either<Failure, CrawlShareCardData>> getShareCardData(
    String crawlId,
  ) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      final model = await remoteDataSource.getShareCardData(crawlId, userId);
      return Right(model);
    } catch (e, st) {
      return Left(_mapToFailure(e, st));
    }
  }

  Failure _mapToFailure(Object e, StackTrace st) {
    if (e is Failure) return e;
    if (e is CrawlDataSourceException) {
      return Failure(e.message);
    }
    return Failure(e.toString());
  }
}
