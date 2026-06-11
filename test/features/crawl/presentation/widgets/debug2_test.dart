import 'dart:async';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/core/services/gps_service.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/features/crawl/domain/entities/crawl_detail.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stamp.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stop.dart';
import 'package:nook/features/crawl/domain/entities/stamp_claim_result.dart';
import 'package:nook/features/crawl/domain/use_cases/claim_stamp_usecase.dart';
import 'package:nook/features/crawl/domain/use_cases/get_crawl_detail_usecase.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_bloc.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_state.dart';
import 'package:nook/features/crawl/presentation/pages/stamp_claim_page.dart';
import 'stamp_claim_page_test.mocks.dart';

void main() {
  testWidgets('debug GPS denied - pump sequence', (tester) async {
    final mockClaimUseCase = MockClaimStampUseCase();
    final mockGps = MockGpsService();
    final mockGetDetail = MockGetCrawlDetailUseCase();
    
    when(mockGetDetail.call(any)).thenAnswer((_) async => Right(CrawlDetail(
      crawl: Crawl(id: 'c1', title: 'Test', slug: 'ts', startsAt: DateTime.now(), endsAt: DateTime.now().add(Duration(days: 30)), status: CrawlStatus.active, city: 'C', totalStops: 5),
      stops: [CrawlStop(id: 'stop-1', crawlId: 'c1', cafeId: 'cf1', cafeName: 'Cafe', cafeAddress: 'Addr', cafeLat: 0, cafeLng: 0, stopOrder: 3, tier: 'city')],
    )));
    when(mockGps.getCurrentPosition()).thenAnswer((_) async => GpsResult(denied: true));
    when(mockClaimUseCase.call(crawlId: anyNamed('crawlId'), stopId: anyNamed('stopId'), lat: anyNamed('lat'), lng: anyNamed('lng')))
        .thenAnswer((_) async => Right(StampClaimResult(stamp: CrawlStamp(id: 'st1', stopId: 'stop-1', cafeId: 'cf1', cafeName: 'Cafe', tier: 'city', claimedAt: DateTime.now(), claimMethod: 'qr'))));

    final bloc = CrawlClaimBloc(claimStampUseCase: mockClaimUseCase, gpsService: mockGps);

    debugPrint('=== BEFORE pumpWidget ===');
    debugPrint('state: ${bloc.state.runtimeType}');

    await tester.pumpWidget(MaterialApp(
      home: StampClaimPage(crawlSlug: 'ts', stopId: 'stop-1', bloc: bloc, getCrawlDetailUseCase: mockGetDetail),
    ));
    
    debugPrint('=== AFTER pumpWidget, BEFORE pump ===');
    debugPrint('state: ${bloc.state.runtimeType}');

    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      debugPrint('pump $i: state=${bloc.state.runtimeType}');
    }

    debugPrint('=== FINAL ===');
    debugPrint('state: ${bloc.state.runtimeType}');
    debugDumpApp();
  });
}
