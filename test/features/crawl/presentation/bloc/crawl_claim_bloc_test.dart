import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/core/services/gps_service.dart';
import 'package:nook/features/crawl/domain/entities/stamp_claim_result.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stamp.dart';
import 'package:nook/features/crawl/domain/failures/crawl_failures.dart';
import 'package:nook/features/crawl/domain/use_cases/claim_stamp_usecase.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_bloc.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_event.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_state.dart';

@GenerateNiceMocks([
  MockSpec<ClaimStampUseCase>(),
  MockSpec<GpsService>(),
])
import 'crawl_claim_bloc_test.mocks.dart';

const _crawlId = 'crawl-1';
const _stopId = 'stop-1';
const _crawlTitle = 'Cebu City Crawl';
const _cafeName = 'Coffee Co.';

Position _fakePosition(double lat, double lng) {
  return Position(
    longitude: lng,
    latitude: lat,
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
  });

  tearDown(() {
    bloc.close();
  });

  group('ClaimInitialized', () {
    blocTest<CrawlClaimBloc, CrawlClaimState>(
      'emits [AcquiringGps, ClaimSubmitting, ClaimSuccess] on happy path',
      build: () => bloc,
      setUp: () {
        when(mockGps.getCurrentPosition()).thenAnswer(
          (_) async => GpsResult(position: _fakePosition(10.3, 123.9)),
        );
        when(mockClaimUseCase.call(
          crawlId: anyNamed('crawlId'),
          stopId: anyNamed('stopId'),
          lat: anyNamed('lat'),
          lng: anyNamed('lng'),
        )).thenAnswer(
          (_) async => Right(
            StampClaimResult(stamp: _fakeStamp(), totalStamps: 3),
          ),
        );
      },
      act: (bloc) => bloc.add(
        const ClaimInitialized(
          crawlId: _crawlId,
          stopId: _stopId,
          crawlTitle: _crawlTitle,
          cafeName: _cafeName,
        ),
      ),
      expect: () => [
        isA<AcquiringGps>(),
        isA<ClaimSubmitting>(),
        isA<ClaimSuccess>(),
      ],
    );

    blocTest<CrawlClaimBloc, CrawlClaimState>(
      'emits ClaimSuccessWithTierCompletion when tier is completed',
      build: () => bloc,
      setUp: () {
        when(mockGps.getCurrentPosition()).thenAnswer(
          (_) async => GpsResult(position: _fakePosition(10.3, 123.9)),
        );
        when(mockClaimUseCase.call(
          crawlId: anyNamed('crawlId'),
          stopId: anyNamed('stopId'),
          lat: anyNamed('lat'),
          lng: anyNamed('lng'),
        )).thenAnswer(
          (_) async => Right(
            StampClaimResult(
              stamp: _fakeStamp(),
              totalStamps: 5,
              tierCompletion: TierCompletionResult(
                tierId: 'tier-1',
                tierSlug: 'silver',
                tierName: 'Silver',
                achievementId: 'ach-1',
                earnedAt: DateTime.utc(2026, 1, 1),
              ),
            ),
          ),
        );
      },
      act: (bloc) => bloc.add(
        const ClaimInitialized(
          crawlId: _crawlId,
          stopId: _stopId,
          crawlTitle: _crawlTitle,
          cafeName: _cafeName,
        ),
      ),
      expect: () => [
        isA<AcquiringGps>(),
        isA<ClaimSubmitting>(),
        isA<ClaimSuccessWithTierCompletion>(),
      ],
    );

    blocTest<CrawlClaimBloc, CrawlClaimState>(
      'emits LocationTooFar when distance check fails',
      build: () => bloc,
      setUp: () {
        when(mockGps.getCurrentPosition()).thenAnswer(
          (_) async => GpsResult(position: _fakePosition(10.3, 123.9)),
        );
        when(mockClaimUseCase.call(
          crawlId: anyNamed('crawlId'),
          stopId: anyNamed('stopId'),
          lat: anyNamed('lat'),
          lng: anyNamed('lng'),
        )).thenAnswer(
          (_) async => Left(LocationTooFarFailure(500)),
        );
      },
      act: (bloc) => bloc.add(
        const ClaimInitialized(
          crawlId: _crawlId,
          stopId: _stopId,
          crawlTitle: _crawlTitle,
          cafeName: _cafeName,
        ),
      ),
      expect: () => [
        isA<AcquiringGps>(),
        isA<ClaimSubmitting>(),
        isA<LocationTooFar>(),
      ],
      verify: (bloc) {
        final state = bloc.state as LocationTooFar;
        expect(state.distanceMeters, 500);
      },
    );

    blocTest<CrawlClaimBloc, CrawlClaimState>(
      'emits AlreadyClaimed when stamp was already collected',
      build: () => bloc,
      setUp: () {
        when(mockGps.getCurrentPosition()).thenAnswer(
          (_) async => GpsResult(position: _fakePosition(10.3, 123.9)),
        );
        when(mockClaimUseCase.call(
          crawlId: anyNamed('crawlId'),
          stopId: anyNamed('stopId'),
          lat: anyNamed('lat'),
          lng: anyNamed('lng'),
        )).thenAnswer(
          (_) async => Left(
            AlreadyClaimedFailure(DateTime.utc(2026, 1, 1)),
          ),
        );
      },
      act: (bloc) => bloc.add(
        const ClaimInitialized(
          crawlId: _crawlId,
          stopId: _stopId,
          crawlTitle: _crawlTitle,
          cafeName: _cafeName,
        ),
      ),
      expect: () => [
        isA<AcquiringGps>(),
        isA<ClaimSubmitting>(),
        isA<AlreadyClaimed>(),
      ],
    );

    blocTest<CrawlClaimBloc, CrawlClaimState>(
      'emits GpsDenied when location permission is denied',
      build: () => bloc,
      setUp: () {
        when(mockGps.getCurrentPosition()).thenAnswer(
          (_) async => const GpsResult(denied: true),
        );
      },
      act: (bloc) => bloc.add(
        const ClaimInitialized(
          crawlId: _crawlId,
          stopId: _stopId,
          crawlTitle: _crawlTitle,
          cafeName: _cafeName,
        ),
      ),
      expect: () => [
        isA<AcquiringGps>(),
        isA<GpsDenied>(),
      ],
    );

    blocTest<CrawlClaimBloc, CrawlClaimState>(
      'emits GpsTimeout when GPS times out',
      build: () => bloc,
      setUp: () {
        when(mockGps.getCurrentPosition()).thenAnswer(
          (_) async => const GpsResult(timeout: true),
        );
      },
      act: (bloc) => bloc.add(
        const ClaimInitialized(
          crawlId: _crawlId,
          stopId: _stopId,
          crawlTitle: _crawlTitle,
          cafeName: _cafeName,
        ),
      ),
      expect: () => [
        isA<AcquiringGps>(),
        isA<GpsTimeout>(),
      ],
    );

    blocTest<CrawlClaimBloc, CrawlClaimState>(
      'emits CrawlExpired when the crawl has ended',
      build: () => bloc,
      setUp: () {
        when(mockGps.getCurrentPosition()).thenAnswer(
          (_) async => GpsResult(position: _fakePosition(10.3, 123.9)),
        );
        when(mockClaimUseCase.call(
          crawlId: anyNamed('crawlId'),
          stopId: anyNamed('stopId'),
          lat: anyNamed('lat'),
          lng: anyNamed('lng'),
        )).thenAnswer((_) async => Left(CrawlEndedFailure()));
      },
      act: (bloc) => bloc.add(
        const ClaimInitialized(
          crawlId: _crawlId,
          stopId: _stopId,
          crawlTitle: _crawlTitle,
          cafeName: _cafeName,
        ),
      ),
      expect: () => [
        isA<AcquiringGps>(),
        isA<ClaimSubmitting>(),
        isA<CrawlExpired>(),
      ],
    );

    blocTest<CrawlClaimBloc, CrawlClaimState>(
      'emits StopInactive when the stop is not active',
      build: () => bloc,
      setUp: () {
        when(mockGps.getCurrentPosition()).thenAnswer(
          (_) async => GpsResult(position: _fakePosition(10.3, 123.9)),
        );
        when(mockClaimUseCase.call(
          crawlId: anyNamed('crawlId'),
          stopId: anyNamed('stopId'),
          lat: anyNamed('lat'),
          lng: anyNamed('lng'),
        )).thenAnswer((_) async => Left(StopInactiveFailure()));
      },
      act: (bloc) => bloc.add(
        const ClaimInitialized(
          crawlId: _crawlId,
          stopId: _stopId,
          crawlTitle: _crawlTitle,
          cafeName: _cafeName,
        ),
      ),
      expect: () => [
        isA<AcquiringGps>(),
        isA<ClaimSubmitting>(),
        isA<StopInactive>(),
      ],
    );

    blocTest<CrawlClaimBloc, CrawlClaimState>(
      'emits ClaimNetworkError on generic failure',
      build: () => bloc,
      setUp: () {
        when(mockGps.getCurrentPosition()).thenAnswer(
          (_) async => GpsResult(position: _fakePosition(10.3, 123.9)),
        );
        when(mockClaimUseCase.call(
          crawlId: anyNamed('crawlId'),
          stopId: anyNamed('stopId'),
          lat: anyNamed('lat'),
          lng: anyNamed('lng'),
        )).thenAnswer((_) async => Left(Failure('network error')));
      },
      act: (bloc) => bloc.add(
        const ClaimInitialized(
          crawlId: _crawlId,
          stopId: _stopId,
          crawlTitle: _crawlTitle,
          cafeName: _cafeName,
        ),
      ),
      expect: () => [
        isA<AcquiringGps>(),
        isA<ClaimSubmitting>(),
        isA<ClaimNetworkError>(),
      ],
    );
  });

  group('ClaimRetryRequested', () {
    blocTest<CrawlClaimBloc, CrawlClaimState>(
      're-emits CrawlClaimInitial from error states',
      build: () => bloc,
      seed: () => const GpsDenied(),
      act: (bloc) => bloc.add(const ClaimRetryRequested()),
      expect: () => [isA<CrawlClaimInitial>()],
    );
  });

  group('ClaimResetRequested', () {
    blocTest<CrawlClaimBloc, CrawlClaimState>(
      'resets to CrawlClaimInitial from any state',
      build: () => bloc,
      seed: () => ClaimSuccess(
        StampClaimResult(stamp: _fakeStamp(), totalStamps: 1),
        _crawlTitle,
        _cafeName,
      ),
      act: (bloc) => bloc.add(const ClaimResetRequested()),
      expect: () => [isA<CrawlClaimInitial>()],
    );
  });
}
