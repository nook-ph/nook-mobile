import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/features/crawls/domain/use_cases/get_my_crawls_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/my_crawls_cubit.dart';
import 'package:nook/features/lists/presentation/pages/list_detail_page.dart';
import 'package:nook/features/lists/presentation/pages/list_page.dart';
import 'package:nook/features/lists/presentation/utils/lists_format.dart';
import 'package:nook/features/lists/presentation/widgets/list_cafe_row.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/features/lists/presentation/widgets/ranked_been_list.dart';

import '../crawls/crawl_fixtures.dart';
import 'lists_fixtures.dart';

void main() {
  group('formatting', () {
    test('place counts', () {
      expect(placeCountText(0), '0 places');
      expect(placeCountText(1), '1 place');
      expect(placeCountText(4), '4 places');
    });

    test('relative days are coarse', () {
      final now = DateTime(2026, 10, 2, 9);
      String ago(int days) =>
          relativeDay(now.subtract(Duration(days: days)), now: now);

      expect(ago(0), 'today');
      expect(ago(1), 'yesterday');
      expect(ago(4), '4 days ago');
      expect(ago(8), 'last week');
      expect(ago(21), '3 weeks ago');
      expect(ago(40), 'last month');
      expect(ago(100), '3 months ago');
      expect(ago(500), 'over a year ago');
      // A date in the future is not "in -1 days".
      expect(relativeDay(now.add(const Duration(days: 2)), now: now), 'today');
    });
  });

  group('Lists overview', () {
    Future<void> pump(
      WidgetTester tester,
      List<CafeList> lists, {
      ValueChanged<CafeList>? onOpen,
      VoidCallback? onCreate,
    }) async {
      usePhone(tester, size: const Size(390, 1400));
      final crawls = MyCrawlsCubit(
        getMyCrawlsUseCase: GetMyCrawlsUseCase(FakeCrawlRepository()),
      );
      addTearDown(crawls.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: crawls,
          child: host(
            ListsOverview(
              lists: lists,
              previews: const {},
              onOpenList: onOpen ?? (_) {},
              onCreate: onCreate ?? () {},
            ),
          ),
        ),
      );
      await crawls.load();
      await tester.pump();
    }

    final system = [
      cafeList(id: 'been', name: 'Been', listType: 'been'),
      cafeList(id: 'want', name: 'Want to Try', listType: 'want_to_try'),
    ];

    testWidgets('first run: what each system list is for, and one button', (
      tester,
    ) async {
      var created = 0;
      await pump(tester, system, onCreate: () => created++);

      expect(find.text('Your lists'), findsOneWidget);
      expect(find.text('Cafes you want to visit wait here.'), findsOneWidget);
      expect(
        find.text('Cafes you visit rank themselves here.'),
        findsOneWidget,
      );
      // Want to try leads, Been follows.
      expect(
        tester.getTopLeft(find.text('Want to try')).dy,
        lessThan(tester.getTopLeft(find.text('Been')).dy),
      );
      expect(find.text('Crawls'), findsOneWidget);
      expect(find.text('All lists'), findsOneWidget);
      // The card carries the only New list button.
      expect(find.text('New list'), findsOneWidget);
      expect(find.byType(ListsPillButton), findsOneWidget);

      await tester.tap(find.text('New list'));
      expect(created, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('custom lists are rows, default first, with their counts', (
      tester,
    ) async {
      CafeList? opened;
      await pump(tester, [
        ...system,
        cafeList(
          id: 'old',
          name: 'Best matcha',
          cafeCount: 2,
          lastSavedAt: DateTime(2020),
        ),
        cafeList(
          id: 'new',
          name: 'Study spots',
          cafeCount: 1,
          lastSavedAt: DateTime(2021),
        ),
        cafeList(id: 'fav', name: 'Favorites', cafeCount: 3, isDefault: true),
        cafeList(id: 'empty', name: 'Date-night nooks'),
      ], onOpen: (list) => opened = list);

      expect(find.text('3 places · Default'), findsOneWidget);
      expect(find.text('1 place · over a year ago'), findsOneWidget);
      expect(find.text('No cafes yet'), findsOneWidget);

      double y(String name) => tester.getTopLeft(find.text(name)).dy;
      expect(y('Favorites'), lessThan(y('Study spots')));
      expect(y('Study spots'), lessThan(y('Best matcha')));

      // New list moved into the header; the first-run card is gone.
      expect(find.text('New list'), findsOneWidget);
      expect(find.byType(ListsPillButton), findsNothing);

      await tester.tap(find.text('Best matcha'));
      expect(opened?.id, 'old');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long list name is cut, not overflowed', (tester) async {
      await pump(tester, [
        ...system,
        cafeList(
          id: 'long',
          name: 'Quiet corners for long thesis writing days in Cebu',
          cafeCount: 2,
        ),
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the loading skeleton fits a phone', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(host(const ListsPageSkeleton()));
      expect(find.byType(ListsSkeleton), findsNWidgets(16));
      expect(tester.takeException(), isNull);
    });
  });

  group('List detail', () {
    Future<void> pump(
      WidgetTester tester, {
      required String listType,
      required List<CafeSummary> cafes,
      String title = 'Study spots',
      String? description,
      List<CafeRanking> rankings = const [],
      ValueChanged<CafeSummary>? onMore,
      VoidCallback? onFind,
    }) async {
      usePhone(tester);
      final repo = FakeRankingRepository()..serverRankings = rankings;
      final cubit = rankingCubit(repo);
      addTearDown(cubit.close);
      await cubit.load();
      await tester.pumpWidget(
        BlocProvider<CafeRankingCubit>.value(
          value: cubit,
          child: host(
            ListDetailView(
              title: title,
              listType: listType,
              description: description,
              cafes: cafes,
              onOpenCafe: (_) {},
              onCafeMore: onMore ?? (_) {},
              onFindCafe: onFind ?? () {},
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a custom list: description, count, rating and area', (
      tester,
    ) async {
      CafeSummary? more;
      await pump(
        tester,
        listType: 'custom',
        description: 'Quiet, outlets.',
        cafes: [
          cafe('a', name: 'Tadaima'),
          cafe('b', name: 'Coffee Bear', reviewCount: 0),
        ],
        onMore: (c) => more = c,
      );

      expect(find.text('Study spots'), findsOneWidget);
      expect(find.text('Quiet, outlets. · 2 places'), findsOneWidget);
      expect(find.byType(ListCafeRow), findsNWidgets(2));
      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('· Lahug, Cebu City'), findsOneWidget);
      // An unrated cafe shows where it is and no star.
      expect(find.text('Lahug, Cebu City'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Options for Coffee Bear'));
      expect(more?.id, 'b');
      expect(tester.takeException(), isNull);
    });

    testWidgets('an empty custom list keeps its title and offers a search', (
      tester,
    ) async {
      var found = 0;
      await pump(
        tester,
        listType: 'custom',
        title: 'Date-night nooks',
        cafes: const [],
        onFind: () => found++,
      );

      expect(find.text('Date-night nooks'), findsOneWidget);
      expect(find.text('No cafes in this list yet.'), findsOneWidget);
      expect(
        find.text('Save a cafe from its page and choose this list.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Find a cafe'));
      expect(found, 1);
    });

    testWidgets('an empty Been has no title, only where to start', (
      tester,
    ) async {
      await pump(tester, listType: 'been', title: 'Been', cafes: const []);

      expect(find.text('Been'), findsNothing);
      expect(find.text('Nowhere yet'), findsOneWidget);
      expect(find.text('Find a cafe'), findsOneWidget);
    });

    testWidgets('Been, nothing ranked: the invitation and a Rank per cafe', (
      tester,
    ) async {
      await pump(
        tester,
        listType: 'been',
        title: 'Been',
        cafes: [
          cafe('a', name: 'Tadaima'),
          cafe('b', name: 'Coffee Bear'),
        ],
      );

      expect(find.text('2 places'), findsOneWidget);
      expect(find.text('Turn 2 visits into your ranking'), findsOneWidget);
      expect(find.text('Rank your first cafe'), findsOneWidget);
      expect(find.text('Your Beens · 2'), findsOneWidget);
      expect(find.text('Rank'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Been, ranked: #1, bands, notes, scores and the rest', (
      tester,
    ) async {
      await pump(
        tester,
        listType: 'been',
        title: 'Been',
        cafes: [
          cafe('c', name: 'Sparrow'),
          cafe('b', name: 'Abaca', neighborhood: 'Banilad'),
          cafe('a', name: 'Brew Szn', note: ' Best flat white. '),
        ],
        rankings: [
          ranking('a', RankBucket.liked, 1, 10),
          ranking('b', RankBucket.fine, 1, 5.5),
        ],
      );

      expect(find.text('2 ranked · 1 to rank'), findsOneWidget);
      expect(find.text('Your #1'), findsOneWidget);
      // Once in the #1 card, once in its row.
      expect(find.text('Brew Szn'), findsNWidgets(2));
      expect(find.text('10.0'), findsNWidgets(2));
      expect(find.text('Liked it · 1'), findsOneWidget);
      expect(find.text('It was fine · 1'), findsOneWidget);
      expect(find.text('Not for me · 1'), findsNothing);
      expect(find.text('Not ranked yet · 1'), findsOneWidget);
      // The note stands in for the area on a ranked row.
      expect(find.text('“Best flat white.”'), findsOneWidget);
      expect(find.text('Banilad, Cebu City'), findsOneWidget);
      expect(find.text('5.5'), findsOneWidget);
      expect(find.text('Re-rank'), findsNWidgets(2));
      expect(find.text('Rank'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Not ranked yet · 1')).style?.color,
        ListsTokens.muted,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('everything ranked drops "to rank"', (tester) async {
      await pump(
        tester,
        listType: 'been',
        title: 'Been',
        cafes: [cafe('a')],
        rankings: [ranking('a', RankBucket.disliked, 1, 2.5)],
      );
      expect(find.text('1 ranked'), findsOneWidget);
      expect(find.text('Not for me · 1'), findsOneWidget);
    });

    testWidgets('the loading skeleton fits a phone', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(host(const ListDetailSkeleton()));
      expect(find.byType(ListsSkeleton), findsNWidgets(20));
      expect(tester.takeException(), isNull);
    });
  });

  group('splitBeenList', () {
    test('keeps ranking order and skips rankings not on the list', () {
      final split = splitBeenList(
        [cafe('x'), cafe('b'), cafe('a')],
        [
          ranking('a', RankBucket.liked, 1, 9),
          ranking('ghost', RankBucket.liked, 2, 8),
          ranking('b', RankBucket.fine, 1, 5),
        ],
      );
      expect(split.ranked.map((e) => e.cafe.id), ['a', 'b']);
      expect(split.unranked.map((c) => c.id), ['x']);
    });
  });
}
