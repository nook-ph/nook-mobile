import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_rankings_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/log_cafe_comparison_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/remove_cafe_ranking_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_ranking_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';

CafeRanking r(String id, RankBucket bucket, int pos, double score) =>
    CafeRanking(cafeId: id, bucket: bucket, position: pos, score: score);

/// Ranking-only fake; noSuchMethod covers the rest of ICafeRepository the
/// cubit never touches.
class _FakeRepo implements ICafeRepository {
  List<CafeRanking> serverRankings = [];
  bool failNextSet = false;
  bool failNextRemove = false;
  final comparisons = <(String, String)>[];
  ({String cafeId, RankBucket bucket, int position})? lastSet;

  @override
  Future<List<CafeRanking>> getCafeRankings() async => List.of(serverRankings);

  @override
  Future<List<CafeRanking>> setCafeRanking({
    required String cafeId,
    required RankBucket bucket,
    required int position,
  }) async {
    if (failNextSet) throw Exception('offline');
    lastSet = (cafeId: cafeId, bucket: bucket, position: position);
    // Crude server echo: place the cafe, shift the rest of the bucket.
    serverRankings =
        [
          for (final x in serverRankings)
            if (x.cafeId != cafeId)
              x.bucket == bucket && x.position >= position
                  ? r(x.cafeId, x.bucket, x.position + 1, x.score)
                  : x,
          r(cafeId, bucket, position, 9.9),
        ]..sort((a, b) {
          final byBucket = a.bucket.sortOrder.compareTo(b.bucket.sortOrder);
          return byBucket != 0 ? byBucket : a.position.compareTo(b.position);
        });
    return List.of(serverRankings);
  }

  @override
  Future<void> removeCafeRanking(String cafeId) async {
    if (failNextRemove) throw Exception('offline');
    serverRankings = serverRankings.where((x) => x.cafeId != cafeId).toList();
  }

  @override
  Future<void> logCafeComparison({
    required String winnerCafeId,
    required String loserCafeId,
  }) async {
    comparisons.add((winnerCafeId, loserCafeId));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _FakeRepo repo;
  late CafeRankingCubit cubit;

  setUp(() {
    repo = _FakeRepo();
    cubit = CafeRankingCubit(
      getCafeRankingsUseCase: GetCafeRankingsUseCase(repo),
      setCafeRankingUseCase: SetCafeRankingUseCase(repo),
      removeCafeRankingUseCase: RemoveCafeRankingUseCase(repo),
      logCafeComparisonUseCase: LogCafeComparisonUseCase(repo),
    );
  });

  tearDown(() => cubit.close());

  test('load populates rankings and flips loaded', () async {
    repo.serverRankings = [
      r('a', RankBucket.liked, 1, 10.0),
      r('b', RankBucket.fine, 1, 5.5),
    ];
    expect(cubit.state.loaded, isFalse);
    await cubit.load();
    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.rankedCount, 2);
    expect(cubit.state.overallRankOf('b'), 2);
  });

  test(
    'full session: bucket, comparisons, commit against server echo',
    () async {
      repo.serverRankings = [
        r('a', RankBucket.liked, 1, 10.0),
        r('b', RankBucket.liked, 2, 8.5),
        r('c', RankBucket.liked, 3, 7.0),
      ];
      await cubit.load();

      final session = cubit.startSession('new', RankBucket.liked);
      expect(session.currentOpponent, 'b'); // midpoint of three

      // Better than b, worse than a → position 2.
      cubit.answerComparison(preferredTarget: true);
      expect(cubit.state.session?.currentOpponent, 'a');
      cubit.answerComparison(preferredTarget: false);
      expect(cubit.state.session?.isComplete, isTrue);

      final committed = await cubit.commitSession();
      expect(committed, isNotNull);
      expect(repo.lastSet, (
        cafeId: 'new',
        bucket: RankBucket.liked,
        position: 2,
      ));
      expect(cubit.state.session, isNull);
      expect(cubit.state.overallRankOf('new'), 2);
      // Both answers were logged with the right winners.
      expect(repo.comparisons, [('new', 'b'), ('a', 'new')]);
    },
  );

  test('re-ranking a cafe never compares it against itself', () async {
    repo.serverRankings = [r('solo', RankBucket.liked, 1, 8.5)];
    await cubit.load();
    final session = cubit.startSession('solo', RankBucket.liked);
    expect(session.isComplete, isTrue); // no opponents but itself
  });

  test(
    'commit failure clears the session and keeps rankings untouched',
    () async {
      repo.serverRankings = [r('a', RankBucket.liked, 1, 8.5)];
      await cubit.load();
      repo.failNextSet = true;

      cubit.startSession('new', RankBucket.liked);
      cubit.skipComparisons();
      final committed = await cubit.commitSession();

      expect(committed, isNull);
      expect(cubit.state.session, isNull);
      expect(cubit.state.isPending('new'), isFalse);
      expect(cubit.state.rankedCount, 1); // unchanged
    },
  );

  test('remove is optimistic and rolls back on failure', () async {
    repo.serverRankings = [r('a', RankBucket.liked, 1, 8.5)];
    await cubit.load();
    repo.failNextRemove = true;

    final ok = await cubit.remove('a');
    expect(ok, isFalse);
    expect(cubit.state.rankingFor('a'), isNotNull); // rolled back
  });

  test('reset drops everything', () async {
    repo.serverRankings = [r('a', RankBucket.liked, 1, 8.5)];
    await cubit.load();
    cubit.reset();
    expect(cubit.state.rankedCount, 0);
    expect(cubit.state.loaded, isFalse);
  });
}
