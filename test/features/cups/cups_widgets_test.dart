import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/cafe_details/presentation/guest_action_replay.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_photos_page.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/cups/presentation/cubit/cafe_cups_cubit.dart';
import 'package:nook/features/cups/presentation/pages/cafe_cups_page.dart';
import 'package:nook/features/cups/presentation/widgets/cafe_cups_section.dart';
import 'package:nook/features/cups/presentation/widgets/cup_card_view.dart';
import 'package:nook/features/cups/presentation/widgets/cup_composer_sheet.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/presentation/cubit/cafe_photos_cubit.dart';
import 'package:nook/utils/theme/theme.dart';

import '../../core/analytics/recording_analytics.dart';
import '../gallery/community_photos_fakes.dart';
import '../gallery/gallery_fakes.dart';
import '../lists/lists_fixtures.dart'
    show FakeRankingRepository, ranking, rankingCubit, usePhone;
import '../profile/profile_test_support.dart' show FakeBlockCubit;
import 'cups_fakes.dart';

const _cafe = PickedCafe(id: 'cafe-1', name: 'Kamp Craft Coffee');
final _now = DateTime(2026, 10, 11, 12);

const _menu = [
  CupMenuOption(id: 'm1', name: 'Ensaymada', kind: CupItemKind.food),
  CupMenuOption(id: 'm2', name: 'Spanish latte', kind: CupItemKind.coffee),
];

class _NoCups extends FakeCupsRepository {
  @override
  Future<CafeCups> getCafeCups(
    String cafeId, {
    CupSort sort = CupSort.recommended,
    int? ratingFilter,
    CupItemKind? kind,
    int limit = 10,
    int offset = 0,
  }) async => CafeCups(
    cafeId: cafeId,
    stats: const CupStats(),
    cards: const [],
    total: 0,
    hasMore: false,
  );
}

void main() {
  late RecordingAnalytics analytics;

  setUp(() => analytics = RecordingAnalytics.install(addTearDown));

  group('composer', () {
    late FakeCupsRepository cups;
    late List<CupComposerOutcome?> outcomes;

    setUp(() {
      cups = FakeCupsRepository(now: () => _now);
      outcomes = [];
    });

    Future<void> open(
      WidgetTester tester, {
      CupCard? editing,
      FakeGalleryPhotoPicker? picker,
      CafeRankingCubit? ranking,
      List<CupCard>? myCups,
    }) async {
      usePhone(tester, size: const Size(390, 1200));
      Widget host(Widget child) => ranking == null
          ? child
          : BlocProvider<CafeRankingCubit>.value(value: ranking, child: child);
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          builder: (context, child) => host(child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => outcomes.add(
                  await openCupComposer(
                    context,
                    cafe: _cafe,
                    source: 'test',
                    editing: editing,
                    menu: _menu,
                    myCups: myCups,
                    repository: cups,
                    picker: picker ?? FakeGalleryPhotoPicker(),
                  ),
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    Future<void> done(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    }

    testWidgets('empty: Post stays off and says what is enough', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Add your cup'), findsOneWidget);
      expect(find.text('Kamp Craft Coffee'), findsOneWidget);
      expect(
        find.text('A photo or a note is enough. Stars are up to you.'),
        findsOneWidget,
      );
      // Stars alone are not a cup.
      await tester.tap(find.bySemanticsLabel('5 stars'));
      await tester.pump();
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();
      expect(cups.posts, isEmpty);
      expect(analytics.names, contains('cup_composer_opened'));
    });

    testWidgets('a note alone posts, with no stars', (tester) async {
      await open(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Note (optional)'),
        'Outlets everywhere.',
      );
      await tester.pump();
      expect(find.text('(optional)'), findsOneWidget);
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();

      final post = cups.posts.single;
      expect(post.note, 'Outlets everywhere.');
      expect(post.rating, isNull);
      expect(post.items, isEmpty);
      expect(outcomes.single?.action, CupComposerAction.posted);
      expect(find.text('Cup posted · Marked as Been'), findsOneWidget);
      expect(
        analytics.propertiesOf('cup_posted'),
        containsPair('has_note', true),
      );
      expect(
        analytics.propertiesOf('cup_posted'),
        containsPair('has_rating', false),
      );
      await done(tester);
    });

    group('posting offers "Rank it"', () {
      late FakeRankingRepository rankings;
      late CafeRankingCubit ranker;

      setUp(() {
        rankings = FakeRankingRepository();
        ranker = rankingCubit(rankings);
      });
      tearDown(() => ranker.close());

      Future<void> post(WidgetTester tester) async {
        await open(tester, ranking: ranker);
        await tester.enterText(
          find.widgetWithText(TextField, 'Note (optional)'),
          'Outlets everywhere.',
        );
        await tester.pump();
        await tester.tap(find.text('Post cup'));
        await tester.pumpAndSettle();
      }

      testWidgets('when posting marked an unranked cafe Been', (tester) async {
        await post(tester);
        expect(find.text('Cup posted · Marked as Been'), findsOneWidget);
        expect(find.text('Rank it · ~20 sec'), findsOneWidget);

        await tester.tap(find.text('Rank it · ~20 sec'));
        await tester.pumpAndSettle();
        expect(find.text('How was Kamp Craft Coffee?'), findsOneWidget);
        expect(analytics.names, contains('cup_rank_it_tapped'));
      });

      testWidgets('not when the cafe is already ranked', (tester) async {
        rankings.serverRankings = [ranking('cafe-1', RankBucket.liked, 0, 8.0)];
        await ranker.load();
        await post(tester);
        expect(find.text('Cup posted · Marked as Been'), findsOneWidget);
        expect(find.text('Rank it · ~20 sec'), findsNothing);
        await done(tester);
      });
    });

    test('Rank it: only for a new cup at a Been, unranked cafe', () {
      const marked = CupComposerOutcome(
        CupComposerAction.posted,
        result: CupPostResult(markedBeen: true),
      );
      const posted = CupComposerOutcome(CupComposerAction.posted);
      const updated = CupComposerOutcome(CupComposerAction.updated);
      expect(offersRankIt(marked, ranked: false, been: false), isTrue);
      expect(offersRankIt(posted, ranked: false, been: true), isTrue);
      // Legacy posting marks nothing: no Been, nothing to rank.
      expect(offersRankIt(posted, ranked: false, been: false), isFalse);
      expect(offersRankIt(marked, ranked: true, been: true), isFalse);
      expect(offersRankIt(updated, ranked: false, been: true), isFalse);
    });

    group('a repeat visit', () {
      final earlier = CupCard(
        id: 'old',
        cupId: 'old',
        cafeId: 'cafe-1',
        userId: 'me',
        username: 'me',
        rating: 4,
        isMine: true,
        visitedAt: DateTime(2026, 7, 19),
      );

      testWidgets('shows your last cup and what new stars do', (tester) async {
        await open(tester, myCups: [earlier]);
        expect(find.text('Your last cup here · Jul 19'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Your last cup here, Jul 19, 4 stars'),
          findsOneWidget,
        );
        // No stars yet: the earlier ones stand.
        expect(
          find.text('Your Jul 19 rating (4★) still counts for this cafe.'),
          findsOneWidget,
        );
        await tester.tap(find.bySemanticsLabel('2 stars'));
        await tester.pump();
        expect(
          find.text(
            'Your rating for this cafe now. Replaces your Jul 19 rating (4★).',
          ),
          findsOneWidget,
        );
      });

      testWidgets('reads your cups here when the caller has none', (
        tester,
      ) async {
        cups = FakeCupsRepository(me: 'demo-mae', now: () => _now);
        await open(tester);
        await tester.pumpAndSettle();
        // mae has two cups at every demo cafe, the last rated 5, 3 days ago.
        expect(find.text('Your last of 2 cups here · Oct 8'), findsOneWidget);
        expect(
          find.text('Your Oct 8 rating (5★) still counts for this cafe.'),
          findsOneWidget,
        );
      });

      testWidgets('a first visit says nothing about earlier ones', (
        tester,
      ) async {
        await open(tester);
        await tester.pumpAndSettle();
        expect(find.textContaining('Your last'), findsNothing);
        expect(find.textContaining('still counts'), findsNothing);
      });

      testWidgets('editing says nothing about earlier ones', (tester) async {
        await open(tester, editing: earlier, myCups: [earlier]);
        expect(find.textContaining('Your last'), findsNothing);
        expect(find.textContaining('Replaces'), findsNothing);
      });
    });

    group('a cup kept for signing in again', () {
      setUp(() {
        GuestActionReplay.now = () => _now;
        cupDraftUserId = () => 'user-a';
      });
      tearDown(() {
        GuestActionReplay.now = DateTime.now;
        cupDraftUserId = currentCupUserId;
        discardKeptCupDraft();
      });

      String note(WidgetTester tester) => tester
          .widget<TextField>(find.widgetWithText(TextField, 'Note (optional)'))
          .controller!
          .text;

      testWidgets('comes back for the same account, once', (tester) async {
        debugKeepCupDraft(cafeId: _cafe.id, note: 'Kept', userId: 'user-a');
        await open(tester);
        expect(note(tester), 'Kept');
      });

      testWidgets('never fills another account\'s composer', (tester) async {
        debugKeepCupDraft(cafeId: _cafe.id, note: 'Kept', userId: 'user-b');
        await open(tester);
        expect(note(tester), isEmpty);
      });

      testWidgets('is dropped once it is stale', (tester) async {
        debugKeepCupDraft(
          cafeId: _cafe.id,
          note: 'Kept',
          userId: 'user-a',
          keptAt: _now.subtract(const Duration(hours: 2)),
        );
        await open(tester);
        expect(note(tester), isEmpty);
      });

      testWidgets('a stale one for another cafe is let go too', (tester) async {
        debugKeepCupDraft(
          cafeId: 'elsewhere',
          note: 'Kept',
          userId: 'user-a',
          keptAt: _now.subtract(const Duration(hours: 2)),
        );
        await open(tester);
        expect(note(tester), isEmpty);
        expect(debugHasKeptCupDraft, isFalse);
      });

      testWidgets('is gone after a log out', (tester) async {
        debugKeepCupDraft(cafeId: _cafe.id, note: 'Kept', userId: 'user-a');
        discardKeptCupDraft();
        await open(tester);
        expect(note(tester), isEmpty);
      });
    });

    testWidgets('closing asks before a draft is thrown away', (tester) async {
      await open(tester);
      // Nothing in it yet: Close just closes.
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Add your cup'), findsNothing);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('4 stars'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this cup?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.text('Great'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('Add your cup'), findsNothing);
      expect(outcomes, [null, null]);
    });

    testWidgets('stars are optional and can be cleared', (tester) async {
      await open(tester);
      await tester.tap(find.bySemanticsLabel('4 stars'));
      await tester.pump();
      expect(find.text('Great'), findsOneWidget);
      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(find.text('Great'), findsNothing);
      // Tapping the lit star again clears it too.
      await tester.tap(find.bySemanticsLabel('2 stars'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('2 stars'));
      await tester.pump();
      expect(find.text('Bad'), findsNothing);
    });

    testWidgets('something without a photo, picked from the menu', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Add what you had without a photo'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'What did you have?'),
        'ens',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ensaymada'));
      await tester.pumpAndSettle();
      // A named item alone is refused by the server (cup_empty): it needs a
      // photo or a note to go with it.
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();
      expect(cups.posts, isEmpty);

      await tester.enterText(
        find.widgetWithText(TextField, 'Note (optional)'),
        'Still warm.',
      );
      await tester.pump();
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();

      final item = cups.posts.single.items.single;
      expect(item.hasPhoto, isFalse);
      expect(item.name, 'Ensaymada');
      expect(item.menuItemId, 'm1');
      expect(item.kind, CupItemKind.food);
      await done(tester);
    });

    testWidgets('a new photo has no kind until you pick one', (tester) async {
      await open(
        tester,
        picker: FakeGalleryPhotoPicker(many: [pickedPhoto('latte')]),
      );
      await tester.tap(find.bySemanticsLabel('Add photos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();

      // Nothing is lit: no silent Coffee.
      for (final kind in CupItemKind.values) {
        final chip = tester.getSemantics(find.bySemanticsLabel(kind.label));
        expect(
          chip.flagsCollection.isSelected,
          Tristate.isFalse,
          reason: kind.label,
        );
      }
      expect(find.text('Pick a kind'), findsOneWidget);

      // Posting asks for it instead of guessing.
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();
      expect(cups.posts, isEmpty);
      expect(
        find.text('Pick what each item is: Coffee, Drink, Food or Space.'),
        findsOneWidget,
      );

      // One tap answers it, and the nudge goes.
      await tester.tap(find.bySemanticsLabel('Food'));
      await tester.pump();
      expect(
        find.text('Pick what each item is: Coffee, Drink, Food or Space.'),
        findsNothing,
      );
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();
      expect(cups.posts.single.items.single.kind, CupItemKind.food);
      await done(tester);
    });

    testWidgets('remove is a 44pt target in the corner, clear of the middle', (
      tester,
    ) async {
      await open(
        tester,
        picker: FakeGalleryPhotoPicker(many: [pickedPhoto('latte')]),
      );
      await tester.tap(find.bySemanticsLabel('Add photos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();

      final remove = find.bySemanticsLabel('Remove item 1');
      final tile = find.bySemanticsLabel(RegExp(r'^Photo 1 of 1'));
      final removeBox = tester.getRect(remove);
      final tileBox = tester.getRect(tile);
      expect(removeBox.width, greaterThanOrEqualTo(44));
      expect(removeBox.height, greaterThanOrEqualTo(44));
      // It holds the photo's top-right corner, and a tap in the middle of
      // the photo selects it rather than removing it.
      expect(removeBox.contains(tileBox.topRight.translate(-2, 2)), isTrue);
      expect(removeBox.contains(tileBox.center), isFalse);
      await tester.tap(tile);
      await tester.pump();
      expect(find.text('Pick a kind'), findsOneWidget);

      await tester.tap(remove);
      await tester.pump();
      expect(find.text('Pick a kind'), findsNothing);
    });

    testWidgets('a typed name without a menu match still asks for its kind', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('Add what you had without a photo'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'What did you have?'),
        'House special',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Note (optional)'),
        'Good.',
      );
      await tester.pump();
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();
      expect(cups.posts, isEmpty);
      await tester.tap(find.bySemanticsLabel('Drink'));
      await tester.pump();
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();
      expect(cups.posts.single.items.single.kind, CupItemKind.drink);
      await done(tester);
    });

    testWidgets('legacy backend: a note needs stars for now', (tester) async {
      cups.backend = CupsMode.legacy;
      await open(tester);
      // No kinds and no photo-less items on 1.1.x storage.
      expect(find.text('Add what you had without a photo'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Note (optional)'),
        'Good.',
      );
      await tester.pump();
      expect(find.text('needed with a note for now'), findsOneWidget);
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();
      expect(find.text('Add a star rating to post your note.'), findsOneWidget);
      expect(cups.posts, isEmpty);

      await tester.tap(find.bySemanticsLabel('5 stars'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(cups.posts.single.rating, 5);
      await done(tester);
    });

    testWidgets('editing a cup: prefilled, saves, and deletes', (tester) async {
      final mine = CupCard(
        id: 'c1',
        cupId: 'c1',
        cafeId: 'cafe-1',
        userId: 'me',
        username: 'me',
        rating: 4,
        note: 'Window seat.',
        isMine: true,
        visitedAt: DateTime(2026, 10, 9),
        items: const [
          CupItem(id: 'i1', kind: CupItemKind.food, name: 'Ensaymada'),
        ],
      );
      await open(tester, editing: mine);
      expect(find.text('Edit your cup'), findsOneWidget);
      expect(find.text('Window seat.'), findsOneWidget);
      expect(find.text('Great'), findsOneWidget);
      expect(find.text('Fri, Oct 9'), findsOneWidget);
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(cups.updates.single.rating, 4);
      expect(cups.updates.single.note, 'Window seat.');
      expect(find.text('Cup updated'), findsOneWidget);
      await done(tester);

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete cup'));
      await tester.pumpAndSettle();
      expect(find.text('Delete your cup?'), findsOneWidget);
      await tester.tap(find.text('Delete cup').last);
      await tester.pumpAndSettle();
      expect(cups.deleted.single.id, 'c1');
      expect(analytics.names, contains('cup_deleted'));
      await done(tester);
    });
  });

  group('cafe Cups section', () {
    Future<CafeCupsCubit> pump(
      WidgetTester tester,
      FakeCupsRepository repo, {
      List<String>? taps,
    }) async {
      usePhone(tester, size: const Size(390, 1600));
      final cubit = CafeCupsCubit(repository: repo, cafeId: 'cafe-1');
      addTearDown(cubit.close);
      await cubit.load();
      final block = FakeBlockCubit();
      addTearDown(block.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<CafeCupsCubit>.value(value: cubit),
                  BlocProvider<BlockCubit>.value(value: block),
                ],
                child: CafeCupsSection(
                  onSeeAll: () => taps?.add('all'),
                  onAdd: () => taps?.add('add'),
                  onOpenPhoto: (_, i) => taps?.add('photo $i'),
                  onHelpful: (c) => taps?.add('helpful ${c.username}'),
                  onMore: (c) => taps?.add('more ${c.username}'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return cubit;
    }

    testWidgets('numbers count cups and people who rated; cards show stars '
        'only when given', (tester) async {
      final taps = <String>[];
      await pump(tester, FakeCupsRepository(now: () => _now), taps: taps);

      expect(find.text('Cups'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      // mae rated 5 on one visit, jun 4: two people, 4.5.
      expect(find.text('4.5'), findsOneWidget);
      expect(find.text('· 2 ratings · 4 cups · 7 photos'), findsOneWidget);
      // Two cards on the page; mae's photos and jun's text-only cup.
      expect(find.text('@mae.brews'), findsOneWidget);
      expect(find.bySemanticsLabel('5 out of 5 stars'), findsOneWidget);
      expect(find.text('Helpful · 3'), findsOneWidget);
      // One See all, in the header; the footer is only Add your cup.
      expect(find.text('See all'), findsOneWidget);
      expect(find.textContaining('See all 4'), findsNothing);

      await tester.tap(find.text('Add your cup'));
      await tester.tap(find.text('See all'));
      await tester.tap(find.text('Helpful · 3'));
      expect(taps, ['add', 'all', 'helpful mae.brews']);
    });

    testWidgets('the kind filter narrows the cups, as many as its chip says', (
      tester,
    ) async {
      final cubit = await pump(tester, FakeCupsRepository(now: () => _now));
      // Two cups have food: one with a photo of it, one naming it. The chip
      // counts cups, not the one food photo.
      expect(find.bySemanticsLabel('Food, 2'), findsOneWidget);
      await tester.ensureVisible(find.bySemanticsLabel('Food, 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Food, 2'));
      await tester.pump();
      await tester.pump();
      expect(cubit.state.kind, CupItemKind.food);
      expect(cubit.state.total, 2);
    });

    testWidgets('no cups: asks for the first one', (tester) async {
      final taps = <String>[];
      await pump(tester, _NoCups(), taps: taps);
      expect(find.text('No cups yet'), findsOneWidget);
      expect(find.textContaining('reviews'), findsNothing);
      await tester.tap(find.text('Add your cup'));
      expect(taps, ['add']);
    });
  });

  testWidgets('a long note\'s More and Less are 44pt targets', (tester) async {
    usePhone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 300,
              child: CupNoteText(text: 'Quiet upstairs. ' * 40, maxLines: 2),
            ),
          ),
        ),
      ),
    );
    final more = find.ancestor(
      of: find.text('More'),
      matching: find.byType(ConstrainedBox),
    );
    expect(tester.getSize(more.first).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(more.first).width, greaterThanOrEqualTo(44));
    await tester.tap(find.text('More'));
    await tester.pump();
    final less = find.ancestor(
      of: find.text('Less'),
      matching: find.byType(ConstrainedBox),
    );
    expect(tester.getSize(less.first).height, greaterThanOrEqualTo(44));
    expect(tester.getSize(less.first).width, greaterThanOrEqualTo(44));
  });

  testWidgets('Cups page: Cups and Photos, with honest counts', (tester) async {
    usePhone(tester);
    final repo = FakeCupsRepository(now: () => _now);
    final cups = CafeCupsCubit(
      repository: repo,
      cafeId: 'cafe-1',
      pageSize: CafeCupsCubit.pagePageSize,
    );
    final photos = CafePhotosCubit(
      repository: FakeCommunityPhotosRepository([
        communityPhoto('p1', username: 'sai'),
        communityPhoto('p2', username: 'mae'),
      ]),
      cafeId: 'cafe-1',
    );
    addTearDown(cups.close);
    addTearDown(photos.close);
    await cups.load();
    await photos.load();
    final block = FakeBlockCubit();
    addTearDown(block.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: BlocProvider<BlockCubit>.value(
          value: block,
          child: CafeCupsPage(
            cafe: _cafe,
            cupsCubit: cups,
            photosCubit: photos,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Cups · 4'), findsOneWidget);
    expect(find.text('Photos · 7'), findsOneWidget);
    expect(find.text('Any rating'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('@mae.brews'), findsOneWidget);
    // Chips count cups (2 with food), the Photos tab counts photos.
    expect(find.text('Food 2'), findsOneWidget);

    await tester.tap(find.text('Photos · 7'));
    await tester.pump();
    expect(find.byType(CafePhotosBody), findsOneWidget);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('Cups page header fits at text scale $scale', (tester) async {
      usePhone(tester);
      final repo = FakeCupsRepository(now: () => _now);
      final cups = CafeCupsCubit(
        repository: repo,
        cafeId: 'cafe-1',
        pageSize: CafeCupsCubit.pagePageSize,
      );
      final photos = CafePhotosCubit(
        repository: FakeCommunityPhotosRepository([communityPhoto('p1')]),
        cafeId: 'cafe-1',
      );
      addTearDown(cups.close);
      addTearDown(photos.close);
      await cups.load();
      await photos.load();
      final block = FakeBlockCubit();
      addTearDown(block.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: BlocProvider<BlockCubit>.value(
            value: block,
            child: CafeCupsPage(
              cafe: _cafe,
              cupsCubit: cups,
              photosCubit: photos,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // The segment holds its label, and the bar holds the segment.
      final label = tester.getRect(find.text('Cups · 4'));
      final segment = tester.getRect(
        find
            .ancestor(
              of: find.text('Cups · 4'),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final bar = tester.getRect(find.byType(AppBar));
      final title = tester.getRect(find.text(_cafe.name));
      // The toolbar keeps its full height: the bar is toolbar + toggle.
      expect(bar.height, kToolbarHeight + 60);
      expect(
        segment.top <= label.top && label.bottom <= segment.bottom,
        isTrue,
      );
      expect(segment.bottom <= bar.bottom, isTrue);
      expect(title.bottom <= segment.top, isTrue);
    });
  }
}
