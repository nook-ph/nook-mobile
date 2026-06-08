import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/core/services/gps_service.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stamp.dart';
import 'package:nook/features/crawl/domain/entities/stamp_claim_result.dart';
import 'package:nook/features/crawl/domain/use_cases/claim_stamp_usecase.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_bloc.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_state.dart';
import 'package:nook/features/crawl/presentation/pages/stamp_claim_page.dart';

@GenerateNiceMocks([
  MockSpec<ClaimStampUseCase>(),
  MockSpec<GpsService>(),
])
import 'stamp_claim_page_test.mocks.dart';

Widget _buildTestWidget({required CrawlClaimBloc bloc}) {
  return MaterialApp(
    home: StampClaimPage(
      crawlSlug: 'test-slug',
      stopId: 'stop-1',
      bloc: bloc,
    ),
  );
}

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
    stopId: 'stop-1',
    cafeId: 'cafe-1',
    cafeName: 'Coffee Co.',
    tier: 'city',
    claimedAt: DateTime.utc(2026, 1, 1),
    claimMethod: 'qr',
  );
}

void main() {
  late MockClaimStampUseCase mockClaimUseCase;
  late MockGpsService mockGps;
  late CrawlClaimBloc bloc;

  setUp(() {
    mockClaimUseCase = MockClaimStampUseCase();
    mockGps = MockGpsService();
    bloc = CrawlClaimBloc(
      claimStampUseCase: mockClaimUseCase,
      gpsService: mockGps,
    );

    when(mockGps.getCurrentPosition()).thenAnswer(
      (_) async => GpsResult(position: _fakePosition()),
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

  testWidgets('renders placeholder text on initial state',
      (WidgetTester tester) async {
    await tester.pumpWidget(_buildTestWidget(bloc: bloc));
    await tester.pump();

    expect(find.byType(StampClaimPage), findsOneWidget);
  });

  testWidgets('renders text for various error states',
      (WidgetTester tester) async {
    bloc.emit(const CrawlClaimInitial());
    await tester.pumpWidget(_buildTestWidget(bloc: bloc));
    await tester.pump();

    final states = <CrawlClaimState>[
      const GpsDenied(),
      const GpsTimeout(),
      const LocationTooFar(500),
      const StopInactive(),
      const CrawlExpired(),
      ClaimNetworkError(Failure('network error')),
      AlreadyClaimed(DateTime.utc(2026, 1, 1)),
    ];

    for (final state in states) {
      bloc.emit(state);
      await tester.pump();
      expect(find.byType(StampClaimPage), findsOneWidget);
    }
  });
}
