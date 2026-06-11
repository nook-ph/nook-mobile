import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mockito/annotations.dart';
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

@GenerateNiceMocks([
  MockSpec<ClaimStampUseCase>(),
  MockSpec<GpsService>(),
  MockSpec<GetCrawlDetailUseCase>(),
])
import 'stamp_claim_page_test.mocks.dart';

const _crawlId = 'test-slug';
const _stopId = 'stop-1';
const _crawlTitle = 'Test Crawl';
const _cafeName = 'Coffee Co.';

Position _fakePosition() {
  return Position(
    latitude: 12.34,
    longitude: 56.78,
    timestamp: DateTime.now(),
    accuracy: 10,
    altitude: 0,
    heading: 0,
    speed: 0,
    speedAccuracy: 0,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  );
}

CrawlStamp _fakeStamp() {
  return CrawlStamp(
    id: 'stamp-1',
    stopId: _stopId,
    cafeId: 'cafe-1',
    cafeName: _cafeName,
    stopOrder: 3,
    tier: 'city',
    claimedAt: DateTime.utc(2026, 1, 1),
    claimMethod: 'qr',
  );
}

CrawlStop _fakeStop() {
  return CrawlStop(
    id: _stopId,
    crawlId: _crawlId,
    cafeId: 'cafe-1',
    cafeName: _cafeName,
    cafeAddress: '123 Test St, Test Neighborhood',
    cafeLat: 10.3,
    cafeLng: 123.9,
    stopOrder: 3,
    tier: 'city',
  );
}

CrawlDetail _fakeCrawlDetail() {
  return CrawlDetail(
    crawl: Crawl(
      id: 'crawl-1',
      title: _crawlTitle,
      slug: _crawlId,
      startsAt: DateTime.now(),
      endsAt: DateTime.now().add(const Duration(days: 30)),
      status: CrawlStatus.active,
      city: 'Test City',
      totalStops: 5,
    ),
    stops: [_fakeStop()],
  );
}

void main() {
  late MockClaimStampUseCase mockClaimUseCase;
  late MockGpsService mockGps;
  late MockGetCrawlDetailUseCase mockGetDetail;
  late CrawlClaimBloc bloc;

  setUp(() {
    mockClaimUseCase = MockClaimStampUseCase();
    mockGps = MockGpsService();
    mockGetDetail = MockGetCrawlDetailUseCase();
    bloc = CrawlClaimBloc(
      claimStampUseCase: mockClaimUseCase,
      gpsService: mockGps,
    );

    when(mockGetDetail.call(any)).thenAnswer(
      (_) async => Right(_fakeCrawlDetail()),
    );
    when(mockGps.getCurrentPosition()).thenAnswer(
      (_) async => const GpsResult(denied: true),
    );
    when(mockClaimUseCase.call(
      crawlId: anyNamed('crawlId'),
      stopId: anyNamed('stopId'),
      lat: anyNamed('lat'),
      lng: anyNamed('lng'),
    )).thenAnswer(
      (_) async => Right(StampClaimResult(stamp: _fakeStamp())),
    );
  });

  tearDown(() {
    bloc.close();
  });

  Widget _buildTestWidget() {
    return MaterialApp(
      home: StampClaimPage(
        crawlSlug: _crawlId,
        stopId: _stopId,
        bloc: bloc,
        getCrawlDetailUseCase: mockGetDetail,
      ),
    );
  }

  group('data loading', () {
    testWidgets('shows loading indicator initially',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows cafe info after data loads',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text(_cafeName), findsOneWidget);
      expect(find.text('Part of $_crawlTitle'), findsOneWidget);
    });

    testWidgets('shows stop chip with order and tier',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Stop 3 · City Tier'), findsOneWidget);
    });
  });

  group('GPS states', () {
    testWidgets('shows Acquiring GPS text when acquiring',
        (WidgetTester tester) async {
      bloc.emit(const AcquiringGps(
        crawlId: _crawlId,
        stopId: _stopId,
        crawlTitle: _crawlTitle,
        cafeName: _cafeName,
      ));
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();

      expect(find.text('Acquiring GPS...'), findsOneWidget);
      expect(find.text('Claim Stamp'), findsOneWidget);
    });

    testWidgets('shows GPS denied message', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget());
      // Let _loadPageData and bloc event handler complete
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      expect(find.text('Enable location access in Settings'), findsOneWidget);
    });

    testWidgets('shows Open Settings link when GPS denied',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestWidget());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      expect(find.text('Open Settings'), findsOneWidget);
    });
  });

  group('claim states', () {
    testWidgets('shows loading indicator on button when submitting',
        (WidgetTester tester) async {
      bloc.emit(const ClaimSubmitting(
        crawlId: _crawlId,
        stopId: _stopId,
        crawlTitle: _crawlTitle,
        cafeName: _cafeName,
        lat: 10.3,
        lng: 123.9,
      ));
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows Already Claimed with date', (WidgetTester tester) async {
      final claimedDate = DateTime.utc(2026, 1, 1);
      bloc.emit(AlreadyClaimed(claimedDate));
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();

      expect(find.text('Already Claimed'), findsOneWidget);
      expect(find.textContaining('Claimed on Jan 1, 2026'), findsOneWidget);
    });

    testWidgets('shows distance when too far', (WidgetTester tester) async {
      bloc.emit(const LocationTooFar(500));
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();

      expect(find.text('Too Far Away'), findsOneWidget);
      expect(
        find.textContaining('You need to be at the cafe'),
        findsOneWidget,
      );
      expect(find.textContaining('500 m'), findsOneWidget);
    });

    testWidgets('shows kilometers when far enough', (WidgetTester tester) async {
      bloc.emit(const LocationTooFar(2500));
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();

      expect(find.textContaining('2.5 km'), findsOneWidget);
    });

    testWidgets('shows stamp animation on success',
        (WidgetTester tester) async {
      final result = StampClaimResult(stamp: _fakeStamp());
      await tester.pumpWidget(_buildTestWidget());
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      bloc.emit(ClaimSuccess(result, _crawlTitle, _cafeName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Stop 3 claimed!'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('error states', () {
    testWidgets('shows ended message for CrawlExpired',
        (WidgetTester tester) async {
      bloc.emit(const CrawlExpired());
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();

      expect(find.text('This crawl has ended'), findsOneWidget);
    });

    testWidgets('shows inactive message for StopInactive',
        (WidgetTester tester) async {
      bloc.emit(const StopInactive());
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();

      expect(find.text('This stop is no longer active'), findsOneWidget);
    });

    testWidgets('shows error with retry for ClaimNetworkError',
        (WidgetTester tester) async {
      bloc.emit(ClaimNetworkError(Failure('Network error occurred')));
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();

      expect(find.text('Network error occurred'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows data error when GetCrawlDetailUseCase fails',
        (WidgetTester tester) async {
      when(mockGetDetail.call(any)).thenAnswer(
        (_) async => Left(Failure('Crawl not found')),
      );

      bloc = CrawlClaimBloc(
        claimStampUseCase: mockClaimUseCase,
        gpsService: mockGps,
      );

      await tester.pumpWidget(_buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Crawl not found'), findsOneWidget);
    });
  });

  group('not registered', () {
    testWidgets('shows not registered message', (WidgetTester tester) async {
      bloc.emit(const NotRegistered());
      await tester.pumpWidget(_buildTestWidget());
      await tester.pump();

      expect(
        find.text('You are not registered for this crawl'),
        findsOneWidget,
      );
    });
  });
}
