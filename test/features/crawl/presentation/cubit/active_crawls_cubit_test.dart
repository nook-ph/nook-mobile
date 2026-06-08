import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/features/crawl/domain/use_cases/get_active_crawls_usecase.dart';
import 'package:nook/features/crawl/presentation/cubit/active_crawls_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/active_crawls_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateNiceMocks([
  MockSpec<GetActiveCrawlsUseCase>(),
  MockSpec<SupabaseClient>(),
  MockSpec<GoTrueClient>(),
])
import 'active_crawls_cubit_test.mocks.dart';

Crawl _fakeCrawl(String id) {
  return Crawl(
    id: id,
    title: 'Test Crawl',
    slug: 'test-crawl',
    startsAt: DateTime(2026, 1, 1),
    endsAt: DateTime(2026, 2, 1),
    status: CrawlStatus.active,
    city: 'Cebu City',
    totalStops: 5,
  );
}

void main() {
  late MockGetActiveCrawlsUseCase mockUseCase;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late ActiveCrawlsCubit cubit;

  setUp(() {
    mockUseCase = MockGetActiveCrawlsUseCase();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(mockSupabase.auth).thenReturn(mockAuth);
    when(mockAuth.currentUser).thenReturn(null);

    cubit = ActiveCrawlsCubit(
      getActiveCrawlsUseCase: mockUseCase,
      supabase: mockSupabase,
    );
  });

  tearDown(() {
    cubit.close();
  });

  blocTest<ActiveCrawlsCubit, ActiveCrawlsState>(
    'emits [Loading, Loaded] on success',
    build: () => cubit,
    act: (cubit) => cubit.loadCrawls(),
    setUp: () {
      when(mockUseCase.call()).thenAnswer(
        (_) async => Right([_fakeCrawl('1')]),
      );
    },
    expect: () => [
      isA<ActiveCrawlsLoading>(),
      isA<ActiveCrawlsLoaded>(),
    ],
  );

  blocTest<ActiveCrawlsCubit, ActiveCrawlsState>(
    'emits Empty when list is empty',
    build: () => cubit,
    act: (cubit) => cubit.loadCrawls(),
    setUp: () {
      when(mockUseCase.call()).thenAnswer((_) async => Right([]));
    },
    expect: () => [
      isA<ActiveCrawlsLoading>(),
      isA<ActiveCrawlsEmpty>(),
    ],
  );

  blocTest<ActiveCrawlsCubit, ActiveCrawlsState>(
    'emits Error on failure',
    build: () => cubit,
    act: (cubit) => cubit.loadCrawls(),
    setUp: () {
      when(mockUseCase.call()).thenAnswer(
        (_) async => Left(Failure('fetch failed')),
      );
    },
    expect: () => [
      isA<ActiveCrawlsLoading>(),
      isA<ActiveCrawlsError>(),
    ],
  );
}
