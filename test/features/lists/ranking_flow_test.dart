import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/cafe/domain/entities/cafe_bundle.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_ranking_flow.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/injection_container.dart';

import 'lists_fixtures.dart';

class _NoAnalytics extends AnalyticsService {
  @override
  Future<void> track(
    String cafeId,
    String eventType, {
    Map<String, dynamic>? metadata,
  }) async {}
}

/// Rankings plus the one read the comparison cards make.
class _Repo extends FakeRankingRepository {
  final names = <String, String>{'b': 'Coffee Bear', 'c': 'Abaca'};
  bool failRankings = false;
  int setCalls = 0;

  @override
  Future<List<CafeRanking>> getCafeRankings() {
    if (failRankings) throw Exception('offline');
    return super.getCafeRankings();
  }

  @override
  Future<List<CafeRanking>> setCafeRanking({
    required String cafeId,
    required RankBucket bucket,
    required int position,
  }) {
    setCalls++;
    return super.setCafeRanking(
      cafeId: cafeId,
      bucket: bucket,
      position: position,
    );
  }

  @override
  Future<CafeBundle> getCafeBundleById(
    String cafeId, {
    bool includeMenu = true,
    bool includeReviews = true,
  }) async {
    return CafeBundle(
      details: CafeDetails(
        id: cafeId,
        createdAt: DateTime(2026),
        name: names[cafeId] ?? cafeId,
        description: '',
        address: '',
        neighborhood: 'IT Park',
        city: 'Cebu City',
        lat: 0,
        lng: 0,
        rating: 4.5,
        reviewCount: 3,
        isNew: false,
      ),
    );
  }
}

void main() {
  late _Repo repo;
  late CafeRankingCubit cubit;

  setUp(() async {
    await sl.reset();
    repo = _Repo();
    sl.registerSingleton<AnalyticsService>(_NoAnalytics());
    sl.registerSingleton<ICafeRepository>(repo);
    cubit = rankingCubit(repo);
  });

  tearDown(() async {
    await cubit.close();
    await sl.reset();
  });

  Future<List<RankingFlowOutcome?>> open(WidgetTester tester) async {
    usePhone(tester);
    final results = <RankingFlowOutcome?>[];
    await tester.pumpWidget(
      SheetOpener<RankingFlowOutcome>(
        sheet: CafeRankingFlow(
          cubit: cubit,
          cafeId: 'a',
          cafeName: 'Tadaima',
          cafeLocation: 'Lahug, Cebu City',
        ),
        onResult: results.add,
      ),
    );
    await openSheet(tester);
    return results;
  }

  testWidgets('first rank: three answers with their score ranges', (
    tester,
  ) async {
    final results = await open(tester);

    expect(find.text('How was Tadaima?'), findsOneWidget);
    expect(find.text('Liked it'), findsOneWidget);
    expect(find.text('Scores 7.0 – 10.0'), findsOneWidget);
    expect(find.text('It was fine'), findsOneWidget);
    expect(find.text('Scores 4.0 – 6.9'), findsOneWidget);
    expect(find.text('Not for me'), findsOneWidget);
    expect(find.text('Scores 1.0 – 3.9'), findsOneWidget);
    expect(
      find.text('Already saved to Been — this just ranks it.'),
      findsOneWidget,
    );
    expect(find.text('current'), findsNothing);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(results, [RankingFlowOutcome.skipped]);
    expect(cubit.state.session, isNull);
  });

  testWidgets('nothing to compare against: straight to the first reveal', (
    tester,
  ) async {
    final results = await open(tester);

    await tester.tap(find.text('Liked it'));
    await tester.pumpAndSettle();

    expect(find.text('Tadaima'), findsOneWidget);
    expect(find.text('8.5'), findsOneWidget);
    expect(find.text('Your first ranked cafe'), findsOneWidget);
    expect(find.text('View my list'), findsOneWidget);

    await tester.tap(find.text('Add a note'));
    await tester.pumpAndSettle();
    expect(results, [RankingFlowOutcome.completedAddNote]);
  });

  testWidgets('re-rank: says the current rank and marks its answer', (
    tester,
  ) async {
    repo.serverRankings = [
      ranking('b', RankBucket.liked, 1, 10),
      ranking('a', RankBucket.liked, 2, 8.5),
    ];
    await cubit.load();
    final results = await open(tester);

    expect(
      find.text(
        'Ranked 8.5 · #2 of 2 — answer again to move it. '
        'Skipping keeps this rank.',
      ),
      findsOneWidget,
    );
    expect(find.text('current'), findsOneWidget);
    expect(find.text('Keep current rank'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);
    expect(
      find.text('Already saved to Been — this just ranks it.'),
      findsNothing,
    );

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(results, [RankingFlowOutcome.skipped]);
    // The old ranking is untouched.
    expect(cubit.state.rankingFor('a')?.position, 2);
  });

  testWidgets('compare: two cards, a count, and Back to the answers', (
    tester,
  ) async {
    repo.serverRankings = [ranking('b', RankBucket.liked, 1, 10)];
    await cubit.load();
    await open(tester);

    await tester.tap(find.text('Liked it'));
    await tester.pumpAndSettle();

    expect(find.text('Which did you like more?'), findsOneWidget);
    expect(find.text('1 of 1'), findsOneWidget);
    expect(find.text('Tadaima'), findsOneWidget);
    expect(find.text('Lahug, Cebu City'), findsOneWidget);
    expect(find.text('Coffee Bear'), findsOneWidget);
    expect(find.text('IT Park, Cebu City'), findsOneWidget);
    expect(
      find.text('Your answers order your list — nothing is public.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('How was Tadaima?'), findsOneWidget);
    expect(cubit.state.session, isNull);
  });

  testWidgets('picking the new cafe ranks it first', (tester) async {
    repo.serverRankings = [ranking('b', RankBucket.liked, 1, 10)];
    await cubit.load();
    final results = await open(tester);

    await tester.tap(find.text('Liked it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tadaima'));
    await tester.pumpAndSettle();

    expect(find.text('#1 of 2 · Been'), findsOneWidget);
    expect(cubit.state.rankingFor('a')?.position, 1);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(results, [RankingFlowOutcome.completed]);
  });

  testWidgets('Too close places it beside the cafe on screen', (tester) async {
    repo.serverRankings = [ranking('b', RankBucket.liked, 1, 10)];
    await cubit.load();
    final results = await open(tester);

    await tester.tap(find.text('Liked it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Too close — skip'));
    await tester.pumpAndSettle();

    expect(find.text('#1 of 2 · next to Coffee Bear'), findsOneWidget);

    await tester.tap(find.text('View my list'));
    await tester.pumpAndSettle();
    expect(results, [RankingFlowOutcome.completedViewList]);
  });

  testWidgets('Back returns to the last pair with the earlier pick outlined', (
    tester,
  ) async {
    repo.serverRankings = [
      ranking('b', RankBucket.liked, 1, 10),
      ranking('c', RankBucket.liked, 2, 9),
    ];
    await cubit.load();
    await open(tester);

    await tester.tap(find.text('Liked it'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
    // The midpoint of two opponents is the first.
    expect(find.text('Coffee Bear'), findsOneWidget);

    // Losing to the first moves on to the second.
    await tester.tap(find.text('Coffee Bear'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Abaca'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
    expect(
      find.text('You picked Coffee Bear here. Tap either card to change it.'),
      findsOneWidget,
    );

    Color strokeOf(String name) {
      final card = tester.widget<Container>(
        find
            .ancestor(of: find.text(name), matching: find.byType(Container))
            .first,
      );
      final decoration = card.foregroundDecoration! as BoxDecoration;
      return (decoration.border! as Border).top.color;
    }

    expect(strokeOf('Coffee Bear'), ListsTokens.brand);
    expect(strokeOf('Tadaima'), ListsTokens.border);
  });

  testWidgets('a failed save reports failed and leaves the cafe unranked', (
    tester,
  ) async {
    repo.failSet = true;
    final results = await open(tester);

    await tester.tap(find.text('It was fine'));
    await tester.pumpAndSettle();

    expect(results, [RankingFlowOutcome.failed]);
    expect(cubit.state.rankingFor('a'), isNull);
  });

  testWidgets('rankings that never loaded are read before placing a cafe', (
    tester,
  ) async {
    // The cubit starts unloaded, as after a failed load at sign-in.
    repo.serverRankings = [ranking('b', RankBucket.liked, 1, 10)];
    await open(tester);

    await tester.tap(find.text('Liked it'));
    await tester.pumpAndSettle();

    // Compared against the cafe already there, not saved at #1 unasked.
    expect(find.text('Which did you like more?'), findsOneWidget);
    expect(find.text('Coffee Bear'), findsOneWidget);
    expect(repo.setCalls, 0);
  });

  testWidgets('rankings that cannot be read end the flow without a save', (
    tester,
  ) async {
    repo.failRankings = true;
    final results = await open(tester);

    await tester.tap(find.text('Liked it'));
    await tester.pumpAndSettle();

    expect(results, [RankingFlowOutcome.failed]);
    expect(repo.setCalls, 0);
  });

  testWidgets('a double tap on a comparison saves once and still reveals', (
    tester,
  ) async {
    repo.serverRankings = [ranking('b', RankBucket.liked, 1, 10)];
    await cubit.load();
    final results = await open(tester);

    await tester.tap(find.text('Liked it'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tadaima'));
    // The outgoing card is still on screen while it fades.
    await tester.tap(find.text('Tadaima'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(results, isEmpty);
    expect(repo.setCalls, 1);
    expect(find.text('#1 of 2 · Been'), findsOneWidget);
  });

  testWidgets('Too close does not claim "next to" when it lands elsewhere', (
    tester,
  ) async {
    repo.serverRankings = [
      ranking('b', RankBucket.liked, 1, 10),
      ranking('c', RankBucket.liked, 2, 9),
      ranking('d', RankBucket.liked, 3, 8),
    ];
    await cubit.load();
    await open(tester);

    await tester.tap(find.text('Liked it'));
    await tester.pumpAndSettle();
    // The midpoint of three is the second, Abaca; a skip lands at the top.
    expect(find.text('Abaca'), findsOneWidget);
    await tester.tap(find.text('Too close — skip'));
    await tester.pumpAndSettle();

    expect(cubit.state.rankingFor('a')?.position, 1);
    expect(find.text('#1 of 4 · Been'), findsOneWidget);
    expect(find.textContaining('next to'), findsNothing);
  });

  test('score ranges match the ranking design', () {
    expect(rankBucketRange(RankBucket.liked), 'Scores 7.0 – 10.0');
    expect(rankBucketRange(RankBucket.fine), 'Scores 4.0 – 6.9');
    expect(rankBucketRange(RankBucket.disliked), 'Scores 1.0 – 3.9');
  });
}
