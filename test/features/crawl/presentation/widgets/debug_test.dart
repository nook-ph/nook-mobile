import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/mockito.dart';
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
import 'package:nook/test/features/crawl/presentation/widgets/stamp_claim_page_test.mocks.dart';

void main() {
  testWidgets('debug GPS denied', (tester) async {
    final mockClaimUseCase = MockClaimStampUseCase();
    final mockGps = MockGpsService();
    final mockGetDetail = MockGetCrawlDetailUseCase();
    
    when(mockGetDetail.call(any)).thenAnswer((_) async => Right(CrawlDetail(
      crawl: Crawl(id: 'c1', title: 'Test', slug: 'ts', startsAt: DateTime.now(), endsAt: DateTime.now().add(Duration(days: 30)), status: CrawlStatus.active, city: 'C', totalStops: 5),
      stops: [CrawlStop(id: 's1', crawlId: 'c1', cafeId: 'cf1', cafeName: 'Cafe', cafeAddress: 'Addr', cafeLat: 0, cafeLng: 0, stopOrder: 3, tier: 'city')],
    )));
    when(mockGps.getCurrentPosition()).thenAnswer((_) async => GpsResult(denied: true));
    when(mockClaimUseCase.call(crawlId: anyNamed('crawlId'), stopId: anyNamed('stopId'), lat: anyNamed('lat'), lng: anyNamed('lng')))
        .thenAnswer((_) async => Right(StampClaimResult(stamp: CrawlStamp(id: 'st1', stopId: 's1', cafeId: 'cf1', cafeName: 'Cafe', tier: 'city', claimedAt: DateTime.now(), claimMethod: 'qr'))));

    final bloc = CrawlClaimBloc(claimStampUseCase: mockClaimUseCase, gpsService: mockGps);

    await tester.pumpWidget(MaterialApp(
      home: StampClaimPage(crawlSlug: 'ts', stopId: 's1', bloc: bloc, getCrawlDetailUseCase: mockGetDetail),
    ));
    
    debugPrint('INITIAL state: ${bloc.state.runtimeType}');
    
    await tester.pump();
    debugPrint('AFTER 1st pump state: ${bloc.state.runtimeType}');
    debugPrint('Data loaded: ${(tester.widgetList(find.byType(StampClaimPage)).first as dynamic).key}');
    
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      debugPrint('Pump $i state: ${bloc.state.runtimeType}');
    }
    
    debugPrint('FINAL state: ${bloc.state.runtimeType}');
    debugPrint('Has GpsDenied text: ${find.text("Enable location access in Settings").evaluate().length}');
    debugPrint('Widget tree dump:');
    debugDumpApp();
  });
}
