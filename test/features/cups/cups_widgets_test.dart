import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_photos_page.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/cups/presentation/cubit/cafe_cups_cubit.dart';
import 'package:nook/features/cups/presentation/pages/cafe_cups_page.dart';
import 'package:nook/features/cups/presentation/widgets/cafe_cups_section.dart';
import 'package:nook/features/cups/presentation/widgets/cup_composer_sheet.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/presentation/cubit/cafe_photos_cubit.dart';
import 'package:nook/utils/theme/theme.dart';

import '../../core/analytics/recording_analytics.dart';
import '../gallery/community_photos_fakes.dart';
import '../gallery/gallery_fakes.dart';
import '../lists/lists_fixtures.dart' show usePhone;
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

    Future<void> open(WidgetTester tester, {CupCard? editing}) async {
      usePhone(tester, size: const Size(390, 1200));
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
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
                    repository: cups,
                    picker: FakeGalleryPhotoPicker(),
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
        find.text(
          'A photo, what you had, or a note is enough. Stars are up to you.',
        ),
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
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();

      final item = cups.posts.single.items.single;
      expect(item.hasPhoto, isFalse);
      expect(item.name, 'Ensaymada');
      expect(item.menuItemId, 'm1');
      expect(item.kind, CupItemKind.food);
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
      expect(find.text('See all 4 cups'), findsOneWidget);

      await tester.tap(find.text('Add your cup'));
      await tester.tap(find.text('See all 4 cups'));
      await tester.tap(find.text('Helpful · 3'));
      expect(taps, ['add', 'all', 'helpful mae.brews']);
    });

    testWidgets('the kind filter narrows the cups', (tester) async {
      final cubit = await pump(tester, FakeCupsRepository(now: () => _now));
      expect(find.bySemanticsLabel('Food, 1'), findsOneWidget);
      await tester.ensureVisible(find.bySemanticsLabel('Food, 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Food, 1'));
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
    expect(find.text('Food 1'), findsOneWidget);

    await tester.tap(find.text('Photos · 7'));
    await tester.pump();
    expect(find.byType(CafePhotosBody), findsOneWidget);
  });
}
