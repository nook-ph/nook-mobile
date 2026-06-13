import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/features/crawl/domain/entities/crawl_detail.dart';
import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';
import 'package:nook/features/crawl/domain/entities/stamp_claim_result.dart';
import 'package:nook/features/crawl/domain/repositories/i_crawl_repository.dart';
import 'package:nook/features/crawl/domain/use_cases/get_share_card_data_usecase.dart';
import 'package:nook/features/crawl/presentation/cubit/share_card_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/share_card_state.dart';
import 'package:nook/features/crawl/presentation/pages/share_activity_page.dart';

CrawlShareCardData _stubData() {
  final now = DateTime(2026, 8, 1);
  return CrawlShareCardData(
    userName: 'Nook Explorer',
    crawlTitle: 'Cebu Island Crawl',
    crawlPeriod: 'Jul\u2013Aug 2026',
    totalStamps: 3,
    totalStops: 12,
    stops: [
      CrawlStopShareItem(
        stopOrder: 1, tier: 'city', cafeName: 'Cafe Brindle',
        isClaimed: true, claimedAt: now.subtract(const Duration(days: 17)),
      ),
      CrawlStopShareItem(
        stopOrder: 3, tier: 'city', cafeName: 'At 5AM Coffee',
        isClaimed: true, claimedAt: now.subtract(const Duration(days: 12)),
      ),
      CrawlStopShareItem(
        stopOrder: 5, tier: 'city', cafeName: 'Kalma Cafe',
        isClaimed: true, claimedAt: now.subtract(const Duration(days: 1)),
      ),
      for (var i = 2; i <= 12; i++)
        if (i != 3 && i != 5)
          CrawlStopShareItem(
            stopOrder: i, tier: 'city', cafeName: 'Cafe $i',
            isClaimed: false,
          ),
    ],
  );
}

class _StubRepository implements ICrawlRepository {
  @override
  Future<Either<Failure, CrawlShareCardData>> getShareCardData(String crawlId) async {
    return Right(_stubData());
  }

  @override
  Future<Either<Failure, List<Crawl>>> getActiveCrawls() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, CrawlDetail>> getCrawlBySlug(String slug) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> registerForCrawl(String crawlId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, StampClaimResult>> claimStamp({
    required String crawlId, required String stopId,
    required double lat, required double lng,
  }) =>
      throw UnimplementedError();
}

class _StubUseCase extends GetShareCardDataUseCase {
  _StubUseCase() : super(_StubRepository());
}

class _MockShareCardCubit extends ShareCardCubit {
  _MockShareCardCubit() : super(getShareCardDataUseCase: _StubUseCase()) {
    emit(ShareCardReady(_stubData()));
  }

  @override
  Future<void> loadData(String crawlId) async {
    emit(ShareCardReady(_stubData()));
  }
}

@Preview(name: 'Share Activity Page', group: 'Crawl Share')
Widget shareActivityPagePreview() {
  final cubit = _MockShareCardCubit();

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ShareActivityPage(
      crawlId: 'preview-crawl',
      crawlTitle: 'Cebu Island Crawl',
      cubit: cubit,
    ),
  );
}
