import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/features/crawl/domain/entities/crawl_detail.dart';
import 'package:nook/features/crawl/domain/failures/crawl_failures.dart';
import 'package:nook/features/crawl/domain/use_cases/get_crawl_detail_usecase.dart';
import 'package:nook/features/crawl/domain/use_cases/register_for_crawl_usecase.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_detail_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/crawl_detail_state.dart';

@GenerateNiceMocks([
  MockSpec<GetCrawlDetailUseCase>(),
  MockSpec<RegisterForCrawlUseCase>(),
])
import 'crawl_detail_cubit_test.mocks.dart';

Crawl _fakeCrawl() {
  return Crawl(
    id: 'crawl-1',
    title: 'Test Crawl',
    slug: 'test-crawl',
    startsAt: DateTime(2026, 1, 1),
    endsAt: DateTime(2026, 2, 1),
    status: CrawlStatus.active,
    city: 'Cebu City',
    totalStops: 5,
  );
}

CrawlDetail _fakeDetail() {
  return CrawlDetail(
    crawl: _fakeCrawl(),
    isRegistered: false,
    stops: [],
    tiers: [],
  );
}

void main() {
  late MockGetCrawlDetailUseCase mockGetDetail;
  late MockRegisterForCrawlUseCase mockRegister;
  late CrawlDetailCubit cubit;

  setUp(() {
    mockGetDetail = MockGetCrawlDetailUseCase();
    mockRegister = MockRegisterForCrawlUseCase();
    cubit = CrawlDetailCubit(
      getCrawlDetailUseCase: mockGetDetail,
      registerForCrawlUseCase: mockRegister,
    );
  });

  tearDown(() {
    cubit.close();
  });

  group('loadDetail', () {
    blocTest<CrawlDetailCubit, CrawlDetailState>(
      'emits [Loading, Loaded] on success',
      build: () => cubit,
      act: (cubit) => cubit.loadDetail('test-crawl'),
      setUp: () {
        when(mockGetDetail.call('test-crawl')).thenAnswer(
          (_) async => Right(_fakeDetail()),
        );
      },
      expect: () => [
        isA<CrawlDetailLoading>(),
        isA<CrawlDetailLoaded>(),
      ],
    );

    blocTest<CrawlDetailCubit, CrawlDetailState>(
      'emits [Loading, Error] on CrawlNotFoundFailure',
      build: () => cubit,
      act: (cubit) => cubit.loadDetail('test-crawl'),
      setUp: () {
        when(mockGetDetail.call('test-crawl')).thenAnswer(
          (_) async => Left(CrawlNotFoundFailure()),
        );
      },
      expect: () => [
        isA<CrawlDetailLoading>(),
        isA<CrawlDetailError>(),
      ],
    );

    blocTest<CrawlDetailCubit, CrawlDetailState>(
      'emits [Loading, Error] on generic failure',
      build: () => cubit,
      act: (cubit) => cubit.loadDetail('test-crawl'),
      setUp: () {
        when(mockGetDetail.call('test-crawl')).thenAnswer(
          (_) async => Left(Failure('oops')),
        );
      },
      expect: () => [
        isA<CrawlDetailLoading>(),
        isA<CrawlDetailError>(),
      ],
    );
  });

  group('register', () {
    blocTest<CrawlDetailCubit, CrawlDetailState>(
      're-fetches detail on successful registration',
      build: () => cubit,
      seed: () => CrawlDetailLoaded(_fakeDetail()),
      act: (cubit) => cubit.register(),
      setUp: () {
        when(mockRegister.call('crawl-1')).thenAnswer(
          (_) async => const Right(unit),
        );
        when(mockGetDetail.call('test-crawl')).thenAnswer(
          (_) async => Right(_fakeDetail()),
        );
      },
      expect: () => [
        isA<CrawlDetailLoading>(),
        isA<CrawlDetailRegisterSuccess>(),
      ],
      verify: (_) {
        verify(mockRegister.call('crawl-1')).called(1);
        verify(mockGetDetail.call('test-crawl')).called(1);
      },
    );

    blocTest<CrawlDetailCubit, CrawlDetailState>(
      're-fetches silently when AlreadyRegisteredFailure',
      build: () => cubit,
      seed: () => CrawlDetailLoaded(_fakeDetail()),
      act: (cubit) => cubit.register(),
      setUp: () {
        when(mockRegister.call('crawl-1')).thenAnswer(
          (_) async => Left(AlreadyRegisteredFailure()),
        );
        when(mockGetDetail.call('test-crawl')).thenAnswer(
          (_) async => Right(_fakeDetail()),
        );
      },
      expect: () => [
        isA<CrawlDetailLoading>(),
        isA<CrawlDetailLoaded>(),
      ],
    );

    blocTest<CrawlDetailCubit, CrawlDetailState>(
      'emits Error when registration fails',
      build: () => cubit,
      seed: () => CrawlDetailLoaded(_fakeDetail()),
      act: (cubit) => cubit.register(),
      setUp: () {
        when(mockRegister.call('crawl-1')).thenAnswer(
          (_) async => Left(Failure('registration failed')),
        );
      },
      expect: () => [
        isA<CrawlDetailError>(),
      ],
    );

    blocTest<CrawlDetailCubit, CrawlDetailState>(
      'does nothing when state is not Loaded',
      build: () => cubit,
      seed: () => const CrawlDetailInitial(),
      act: (cubit) => cubit.register(),
      expect: () => [],
    );
  });

  group('refresh', () {
    blocTest<CrawlDetailCubit, CrawlDetailState>(
      're-fetches detail when state is CrawlDetailLoaded',
      build: () => cubit,
      seed: () => CrawlDetailLoaded(_fakeDetail()),
      act: (cubit) => cubit.refresh(),
      setUp: () {
        when(mockGetDetail.call('test-crawl')).thenAnswer(
          (_) async => Right(_fakeDetail()),
        );
      },
      expect: () => [
        isA<CrawlDetailLoading>(),
        isA<CrawlDetailLoaded>(),
      ],
      verify: (_) {
        verify(mockGetDetail.call('test-crawl')).called(1);
      },
    );

    blocTest<CrawlDetailCubit, CrawlDetailState>(
      're-fetches detail when state is CrawlDetailRegisterSuccess',
      build: () => cubit,
      seed: () => CrawlDetailRegisterSuccess(_fakeDetail()),
      act: (cubit) => cubit.refresh(),
      setUp: () {
        when(mockGetDetail.call('test-crawl')).thenAnswer(
          (_) async => Right(_fakeDetail()),
        );
      },
      expect: () => [
        isA<CrawlDetailLoading>(),
        isA<CrawlDetailLoaded>(),
      ],
    );

    blocTest<CrawlDetailCubit, CrawlDetailState>(
      'does nothing when state is not Loaded or RegisterSuccess',
      build: () => cubit,
      seed: () => const CrawlDetailInitial(),
      act: (cubit) => cubit.refresh(),
      expect: () => [],
    );
  });
}
