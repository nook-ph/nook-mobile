import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/pages/gallery_viewer_page.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_photo_options.dart';
import 'package:nook/features/gallery/presentation/widgets/profile_gallery_tab.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/utils/theme/theme.dart';

import '../lists/lists_fixtures.dart' show usePhone;
import 'gallery_fakes.dart';

void main() {
  late FakeGalleryRepository repo;
  late GalleryCubit cubit;
  late int adds;
  late List<String> openedCafes;
  late int openedReviews;

  setUp(() {
    adds = 0;
    openedCafes = [];
    openedReviews = 0;
  });

  tearDown(() => cubit.close());

  Future<void> pump(WidgetTester tester, List<GalleryPhoto> photos) async {
    usePhone(tester);
    repo = FakeGalleryRepository(photos);
    cubit = GalleryCubit(repository: repo);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ProfileGalleryTab(
                onAdd: () => adds++,
                onOpen: (photo) => GalleryViewerPage.open(
                  context,
                  photo: photo,
                  onOpenCafe: openedCafes.add,
                  onOpenReview: () => openedReviews++,
                ),
                onOptions: (photo) => showGalleryPhotoOptions(
                  context,
                  cubit: cubit,
                  photo: photo,
                  onOpenReview: () => openedReviews++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> letToastExpire(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  Finder tile(String drink) =>
      find.bySemanticsLabel(RegExp('^${RegExp.escape(drink)}, at '));

  testWidgets('a failed upload shows its tile even when the gallery failed '
      'to load', (tester) async {
    usePhone(tester);
    repo = FakeGalleryRepository()..readFailure = Exception('offline');
    cubit = GalleryCubit(repository: repo);
    await cubit.load();
    expect(cubit.state.status, GalleryStatus.failed);
    repo.writeFailure = Exception('offline');
    await cubit.upload(
      cafeId: 'cafe-9',
      photos: [pickedPhoto('a')],
      source: GalleryPhotoSource.gallery,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: ProfileGalleryTab(
              onAdd: () {},
              onOpen: (_) {},
              onOptions: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Didn’t upload'), findsOneWidget);
    expect(find.bySemanticsLabel('Retry upload'), findsOneWidget);
    expect(
      find.text('Could not load the rest of your gallery.'),
      findsOneWidget,
    );
  });

  group('grid', () {
    testWidgets('a moderated photo says it was removed by Nook (NH3)', (
      tester,
    ) async {
      await pump(tester, [
        galleryPhoto('a', drink: 'Flat white'),
        galleryPhoto('b', drink: 'Cortado', moderated: true),
      ]);
      expect(find.text('Removed by Nook'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('^Cortado, .*removed by Nook')),
        findsOneWidget,
      );
    });

    testWidgets('hidden photos stay in the grid, marked as hidden', (
      tester,
    ) async {
      await pump(tester, [
        galleryPhoto('a', drink: 'Flat white'),
        galleryPhoto('b', drink: 'Cortado', cafeId: 'cafe-2'),
        galleryPhoto('c', drink: 'Mocha', hidden: true),
      ]);
      // The counts line is gone; the header's Cups stat carries the count.
      expect(find.textContaining(' cups'), findsNothing);
      expect(find.byType(GalleryTile), findsNWidgets(3));
      expect(
        find.bySemanticsLabel(
          'Mocha, at Kamp Craft Coffee, hidden from your '
          'profile',
        ),
        findsOneWidget,
      );
    });

    testWidgets('pinned photos come first and say so', (tester) async {
      await pump(tester, [
        galleryPhoto('new', drink: 'Newest', takenAt: DateTime(2026, 9)),
        galleryPhoto(
          'pin',
          drink: 'Pinned one',
          takenAt: DateTime(2020),
          pin: 1,
        ),
      ]);
      final tiles = tester.widgetList<GalleryTile>(find.byType(GalleryTile));
      expect(tiles.first.photo.id, 'pin');
      expect(
        find.bySemanticsLabel('Pinned one, at Kamp Craft Coffee, pinned'),
        findsOneWidget,
      );
    });

    testWidgets('empty: says what belongs here and offers Add photos', (
      tester,
    ) async {
      await pump(tester, []);
      expect(find.text('Your coffee, cup by cup'), findsOneWidget);
      expect(find.textContaining('Photos in your reviews'), findsOneWidget);
      await tester.tap(find.text('Add photos'));
      expect(adds, 1);
    });

    testWidgets('a failed load offers to try again', (tester) async {
      usePhone(tester);
      repo = FakeGalleryRepository([galleryPhoto('a')])
        ..readFailure = Exception('offline');
      cubit = GalleryCubit(repository: repo);
      await cubit.load();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: Scaffold(
              body: ProfileGalleryTab(
                onAdd: () {},
                onOpen: (_) {},
                onOptions: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Could not load your gallery.'), findsOneWidget);
      repo.readFailure = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryTile), findsOneWidget);
    });
  });

  group('options', () {
    testWidgets('long-press, Pin to top pins it', (tester) async {
      await pump(tester, [galleryPhoto('a', drink: 'Flat white')]);
      await tester.longPress(tile('Flat white'));
      await tester.pumpAndSettle();
      expect(
        find.text('Pinned photos show first · 0 of 3 pinned'),
        findsOneWidget,
      );

      await tester.tap(find.text('Pin to top'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['pin a 1']);
      expect(cubit.state.photos.single.isPinned, isTrue);
      await letToastExpire(tester);
    });

    testWidgets('a fourth pin says to unpin one first', (tester) async {
      await pump(tester, [
        galleryPhoto('p1', pin: 1),
        galleryPhoto('p2', pin: 2),
        galleryPhoto('p3', pin: 3),
        galleryPhoto('a', drink: 'Flat white'),
      ]);
      await tester.longPress(tile('Flat white'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pin to top'));
      await tester.pumpAndSettle();
      expect(
        find.text('You can pin 3 photos. Unpin one first.'),
        findsOneWidget,
      );
      expect(repo.calls, isEmpty);
      await letToastExpire(tester);
    });

    testWidgets('Hide from profile dims it and says only you see it', (
      tester,
    ) async {
      await pump(tester, [galleryPhoto('a', drink: 'Flat white')]);
      await tester.longPress(tile('Flat white'));
      await tester.pumpAndSettle();
      expect(
        find.text('Only you will see it. You can show it again any time.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Hide from profile'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['hide a true']);
      expect(
        find.bySemanticsLabel(
          'Flat white, at Kamp Craft Coffee, hidden from your profile',
        ),
        findsOneWidget,
      );
      await letToastExpire(tester);

      // And back.
      await tester.longPress(tile('Flat white'));
      await tester.pumpAndSettle();
      expect(find.text('Pin to top'), findsNothing);
      await tester.tap(find.text('Show on profile'));
      await tester.pumpAndSettle();
      expect(repo.calls.last, 'hide a false');
      await letToastExpire(tester);
    });

    // A review photo stays on the review (cafe page, the profile's Reviews
    // tab), so "Only you will see it" would be false.
    testWidgets('hiding a review photo says it still shows on the review', (
      tester,
    ) async {
      await pump(tester, [
        galleryPhoto(
          'r',
          drink: 'Flat white',
          source: GalleryPhotoSource.review,
        ),
      ]);
      await tester.longPress(tile('Flat white'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Only you will see it'), findsNothing);
      expect(
        find.text('Takes it off your gallery. It still shows on your review.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Hide from profile'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['hide r true']);
      expect(find.text('Hidden from your gallery'), findsOneWidget);
      await letToastExpire(tester);
    });

    testWidgets('Delete asks first, and Cancel keeps the photo', (
      tester,
    ) async {
      await pump(tester, [galleryPhoto('a', drink: 'Flat white')]);
      await tester.longPress(tile('Flat white'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete photo'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this photo?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.calls, isEmpty);
      expect(find.byType(GalleryTile), findsOneWidget);
    });

    testWidgets('Delete, confirmed, removes it', (tester) async {
      await pump(tester, [
        galleryPhoto('a', drink: 'Flat white'),
        galleryPhoto('b', drink: 'Cortado'),
      ]);
      await tester.longPress(tile('Flat white'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete photo'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(GestureDetector, 'Delete photo').last,
      );
      await tester.pumpAndSettle();
      expect(repo.calls, ['delete a']);
      expect(find.byType(GalleryTile), findsOneWidget);
      expect(find.text('Photo deleted'), findsOneWidget);
      await letToastExpire(tester);
    });

    testWidgets('a review photo offers its review, never Delete', (
      tester,
    ) async {
      await pump(tester, [
        galleryPhoto(
          'r',
          drink: 'Pour over',
          source: GalleryPhotoSource.review,
        ),
      ]);
      await tester.longPress(tile('Pour over'));
      await tester.pumpAndSettle();
      expect(find.text('Delete photo'), findsNothing);
      await tester.tap(find.text('Part of your review'));
      await tester.pumpAndSettle();
      expect(openedReviews, 1);
    });

    testWidgets('Add what you had saves a drink name', (tester) async {
      await pump(tester, [galleryPhoto('a')]);
      await tester.longPress(tile('Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add what you had'));
      await tester.pumpAndSettle();
      expect(find.text('Edit photo'), findsOneWidget);
      // Nothing changed yet: Save is off (Figma G6).
      expect(_saveOn(tester), isFalse);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Edit photo'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Drink (optional)'),
        'Ube latte',
      );
      await tester.pump();
      expect(_saveOn(tester), isTrue);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['details a Ube latte null']);
      expect(cubit.state.photos.single.drinkName, 'Ube latte');
    });
  });

  group('viewer', () {
    testWidgets('shows the drink, the cafe chip and where it is', (
      tester,
    ) async {
      await pump(tester, [
        galleryPhoto('a', drink: 'Flat white', takenAt: DateTime(2026, 3, 14)),
        galleryPhoto('b', drink: 'Cortado', takenAt: DateTime(2025, 1, 2)),
      ]);
      await tester.tap(tile('Flat white'));
      await tester.pumpAndSettle();

      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Flat white'), findsOneWidget);
      expect(find.text('March 2026'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Open Kamp Craft Coffee'));
      expect(openedCafes, ['cafe-1']);
    });

    testWidgets('swiping moves to the next photo', (tester) async {
      await pump(tester, [
        galleryPhoto('a', drink: 'Flat white', takenAt: DateTime(2026, 3, 14)),
        galleryPhoto('b', drink: 'Cortado', takenAt: DateTime(2025, 1, 2)),
      ]);
      await tester.tap(tile('Flat white'));
      await tester.pumpAndSettle();
      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('Cortado'), findsOneWidget);
      expect(find.text('January 2025'), findsOneWidget);
    });

    // Pinning re-sorts the gallery. The viewer must keep showing (and act
    // on) the same photo, not whichever photo now sits at the old page.
    testWidgets('pinning from the viewer keeps the same photo on screen', (
      tester,
    ) async {
      await pump(tester, [
        galleryPhoto('a', drink: 'Flat white', takenAt: DateTime(2026, 3, 14)),
        galleryPhoto('b', drink: 'Cortado', takenAt: DateTime(2026, 2, 1)),
        galleryPhoto('c', drink: 'Mocha', takenAt: DateTime(2025, 1, 2)),
      ]);
      await tester.tap(tile('Mocha'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 3'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Photo options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pin to top'));
      await tester.pumpAndSettle();

      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('Mocha'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Mocha at Kamp Craft Coffee'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Cortado at Kamp Craft Coffee'),
        findsNothing,
      );

      // And the options now act on the photo on screen.
      await tester.tap(find.bySemanticsLabel('Photo options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unpin'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['pin c 1', 'pin c null']);
      expect(find.text('3 of 3'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Mocha at Kamp Craft Coffee'),
        findsOneWidget,
      );
      await letToastExpire(tester);
    });

    testWidgets('owner options from the viewer; deleting the last closes it', (
      tester,
    ) async {
      await pump(tester, [galleryPhoto('a', drink: 'Flat white', pin: 1)]);
      await tester.tap(tile('Flat white'));
      await tester.pumpAndSettle();
      expect(find.text('March 2026 · Pinned'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Photo options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete photo'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(GestureDetector, 'Delete photo').last,
      );
      await tester.pumpAndSettle();

      expect(find.byType(GalleryViewerPage), findsNothing);
      expect(find.text('Your coffee, cup by cup'), findsOneWidget);
      await letToastExpire(tester);
    });
  });

  group('uploads', () {
    testWidgets('an uploading photo sits after the pins with a progress bar', (
      tester,
    ) async {
      await pump(tester, [
        galleryPhoto('pinned', pin: 1),
        galleryPhoto('older', takenAt: DateTime(2024)),
      ]);
      repo.writeFailure = Exception('offline');
      await cubit.upload(
        cafeId: 'cafe-9',
        photos: [pickedPhoto('a')],
        source: GalleryPhotoSource.gallery,
      );
      await tester.pump();

      expect(find.text('Didn’t upload'), findsOneWidget);
      final tiles = tester
          .widgetList(
            find.byWidgetPredicate(
              (w) => w is GalleryTile || w is GalleryUploadTile,
            ),
          )
          .toList();
      expect(tiles[0], isA<GalleryTile>());
      expect(tiles[1], isA<GalleryUploadTile>());
      expect(tiles[2], isA<GalleryTile>());

      repo.writeFailure = null;
      await tester.tap(find.bySemanticsLabel('Retry upload'));
      await tester.pumpAndSettle();
      expect(find.byType(GalleryUploadTile), findsNothing);
      expect(find.byType(GalleryTile), findsNWidgets(3));
      expect(repo.added, hasLength(1));
    });

    testWidgets('the first photo uploading replaces the empty state', (
      tester,
    ) async {
      await pump(tester, const []);
      repo.writeFailure = Exception('offline');
      await cubit.upload(
        cafeId: 'cafe-9',
        photos: [pickedPhoto('a')],
        source: GalleryPhotoSource.gallery,
      );
      await tester.pump();
      expect(find.text('Your coffee, cup by cup'), findsNothing);
      expect(find.byType(GalleryUploadTile), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Remove this photo'));
      await tester.pump();
      expect(find.text('Your coffee, cup by cup'), findsOneWidget);
    });
  });

  testWidgets('a failed tile fits at 360 wide and text scale 1.3', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = FakeGalleryRepository()..writeFailure = Exception('offline');
    cubit = GalleryCubit(repository: repo);
    await cubit.load();
    await cubit.upload(
      cafeId: 'cafe-9',
      photos: [pickedPhoto('a')],
      source: GalleryPhotoSource.gallery,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 740),
            textScaler: TextScaler.linear(1.3),
          ),
          child: BlocProvider.value(
            value: cubit,
            child: Scaffold(
              body: ProfileGalleryTab(
                onAdd: () {},
                onOpen: (_) {},
                onOptions: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Didn’t upload'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Undo after Hide shows it again and puts the pin back', (
    tester,
  ) async {
    await pump(tester, [galleryPhoto('a', drink: 'Flat white', pin: 1)]);
    await tester.longPress(tile('Flat white'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide from profile'));
    await tester.pumpAndSettle();
    expect(find.text('Hidden from your profile'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['hide a true', 'hide a false', 'pin a 1']);
    final photo = cubit.state.photos.single;
    expect(photo.isHidden, isFalse);
    expect(photo.pinOrder, 1);
    await letToastExpire(tester);
  });

  group('edit sheet', () {
    testWidgets('Change cafe moves the photo; going back to the same cafe '
        'turns Save off again', (tester) async {
      usePhone(tester);
      final kamp = galleryPhoto('a');
      const lorenzo = PickedCafe(
        id: 'lorenzo',
        name: "Lorenzo's Cafe",
        area: 'Lahug, Cebu City',
      );
      var next = lorenzo;
      PhotoDetails? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showPhotoDetailsSheet(
                  context,
                  photo: kamp,
                  pickCafe: () async => next,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      final change = find.bySemanticsLabel('Cafe: Kamp Craft Coffee. Change');
      expect(change, findsOneWidget);
      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(_saveOn(tester), isTrue);

      next = PickedCafe(id: kamp.cafeId, name: kamp.cafeName);
      await tester.tap(find.bySemanticsLabel("Cafe: Lorenzo's Cafe. Change"));
      await tester.pumpAndSettle();
      expect(_saveOn(tester), isFalse);

      next = lorenzo;
      await tester.tap(
        find.bySemanticsLabel('Cafe: Kamp Craft Coffee. Change'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result?.cafe, lorenzo);
    });

    testWidgets('a review photo keeps its cafe', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: TAppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPhotoDetailsSheet(
                  context,
                  photo: galleryPhoto('r', source: GalleryPhotoSource.review),
                  pickCafe: () async => null,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cafe:'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('^Cafe:')), findsNothing);
    });
  });
}

/// Whether the edit sheet's Save can be tapped.
bool _saveOn(WidgetTester tester) =>
    tester
        .widget<ListsPillButton>(find.widgetWithText(ListsPillButton, 'Save'))
        .onTap !=
    null;
