import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/gallery_flows.dart';
import 'package:nook/features/gallery/presentation/widgets/cafe_picker_sheet.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_photo_options.dart';
import 'package:nook/features/public_profile/presentation/cubit/profile_visibility_cubit.dart';
import 'package:nook/utils/theme/theme.dart';

import '../lists/lists_fixtures.dart' show usePhone;
import '../public_profile/public_profile_fakes.dart';
import '../cups/cups_fakes.dart';
import 'gallery_fakes.dart';

/// A page with one button that runs [run] from a live context.
Widget _launcher(Future<void> Function(BuildContext) run) => MaterialApp(
  theme: TAppTheme.lightTheme,
  home: Scaffold(
    body: Builder(
      builder: (context) =>
          TextButton(onPressed: () => run(context), child: const Text('go')),
    ),
  ),
);

Future<void> _go(WidgetTester tester) async {
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

Future<void> _letToastExpire(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  final kamp = cafeSummary('kamp', 'Kamp Craft Coffee');
  final lorenzo = cafeSummary('lorenzo', "Lorenzo's Cafe");
  final capu = cafeSummary('capu', 'Capu Coffee');
  final abaca = cafeSummary('abaca', 'Abaca Baking', neighborhood: 'Mactan');

  late FakeGalleryRepository repo;
  late GalleryCubit cubit;

  setUp(() {
    repo = FakeGalleryRepository();
    cubit = GalleryCubit(repository: repo);
  });

  tearDown(() => cubit.close());

  group('cafe picker', () {
    Future<List<PickedCafe?>> openPicker(
      WidgetTester tester,
      FakeCafePickerSource source, {
      Future<dynamic>? takenHere,
    }) async {
      usePhone(tester);
      final picked = <PickedCafe?>[];
      await tester.pumpWidget(
        _launcher(
          (context) async => picked.add(
            await showCafePickerSheet(
              context,
              source: source,
              takenHere: takenHere?.then((c) => c),
            ),
          ),
        ),
      );
      await _go(tester);
      return picked;
    }

    testWidgets('Been cafes, then Nearby without repeats', (tester) async {
      await openPicker(
        tester,
        FakeCafePickerSource(been: [kamp, lorenzo], near: [lorenzo, capu]),
      );
      expect(find.text('Which cafe is this from?'), findsOneWidget);
      expect(find.text('Your Been cafes'), findsOneWidget);
      expect(find.text('Nearby'), findsOneWidget);
      expect(find.text('Taken here?'), findsNothing);
      // Lorenzo's is a Been cafe, so Nearby does not list it again.
      expect(find.text("Lorenzo's Cafe"), findsOneWidget);
      expect(find.text('Capu Coffee'), findsOneWidget);
    });

    testWidgets('caps each section at six', (tester) async {
      await openPicker(
        tester,
        FakeCafePickerSource(
          been: [for (var i = 0; i < 9; i++) cafeSummary('b$i', 'Been $i')],
          near: const [],
        ),
      );
      expect(find.textContaining(RegExp(r'^Been \d$')), findsNWidgets(6));
    });

    testWidgets('a photo-location match leads as "Taken here?"', (
      tester,
    ) async {
      final picked = await openPicker(
        tester,
        FakeCafePickerSource(been: [kamp, abaca], near: const []),
        takenHere: Future.value(abaca),
      );
      expect(find.text('Taken here?'), findsOneWidget);
      // Shown once, as the suggestion, not again under Been.
      expect(find.text('Abaca Baking'), findsOneWidget);
      await tester.tap(find.text('Abaca Baking'));
      await tester.pumpAndSettle();
      expect(picked.single?.id, 'abaca');
    });

    testWidgets('without location, offers to use it', (tester) async {
      final source = FakeCafePickerSource(
        been: [kamp],
        near: null,
        nearAfterAsking: [capu],
      );
      await openPicker(tester, source);
      expect(find.text('Capu Coffee'), findsNothing);
      await tester.tap(find.text('Use my location to see cafes near you'));
      await tester.pumpAndSettle();
      expect(source.asks, 1);
      expect(find.text('Capu Coffee'), findsOneWidget);
    });

    testWidgets('search replaces the sections; no match says so', (
      tester,
    ) async {
      final source = FakeCafePickerSource(
        been: [kamp],
        near: const [],
        results: {
          'abaca': [abaca],
        },
      );
      final picked = await openPicker(tester, source);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Your Been cafes'), findsNothing);
      expect(find.textContaining('No cafes match "zzz"'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Abaca');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(source.searches, ['zzz', 'Abaca']);
      await tester.tap(find.text('Abaca Baking'));
      await tester.pumpAndSettle();
      expect(
        picked.single,
        const PickedCafe(
          id: 'abaca',
          name: 'Abaca Baking',
          area: 'Mactan, Cebu City',
        ),
      );
    });
  });

  group('+ flow', () {
    late FakeCupsRepository cups;

    setUp(() => cups = FakeCupsRepository());

    GalleryFlowDeps deps({
      required FakeGalleryPhotoPicker picker,
      FakeCafePickerSource? cafes,
    }) => GalleryFlowDeps(
      cubit: cubit,
      picker: picker,
      cafes: cafes ?? FakeCafePickerSource(been: [kamp], near: const []),
      cups: cups,
    );

    testWidgets('pick, choose the cafe, then post them as a cup there', (
      tester,
    ) async {
      usePhone(tester);
      final cafes = FakeCafePickerSource(
        been: [kamp, lorenzo],
        near: const [],
        match: lorenzo,
      );
      final picker = FakeGalleryPhotoPicker(
        many: [
          pickedPhoto('a', lat: 10.33, lng: 123.9, takenAt: DateTime(2026, 2)),
          pickedPhoto('b'),
        ],
      );
      await tester.pumpWidget(
        _launcher(
          (context) =>
              addPhotosToGallery(context, deps(picker: picker, cafes: cafes)),
        ),
      );
      await _go(tester);

      // The located photo suggested Lorenzo's.
      expect(cafes.takenAtCalls, [(10.33, 123.9)]);
      expect(find.text('Which cafe are these from?'), findsOneWidget);
      expect(find.text('Taken here?'), findsOneWidget);
      await tester.tap(find.text('Kamp Craft Coffee'));
      await tester.pumpAndSettle();

      // The cup composer, for this cafe, with both photos in it.
      expect(find.text('Add your cup'), findsOneWidget);
      expect(find.text('Kamp Craft Coffee'), findsOneWidget);
      expect(find.text('2 of 10'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'What is it? (optional)'),
        'Iced Spanish latte',
      );
      // The second photo is food.
      await tester.tap(find.bySemanticsLabel(RegExp(r'^Coffee 2 of 2')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Food'));
      await tester.enterText(
        find.widgetWithText(TextField, 'What is it? (optional)'),
        'Banana bread',
      );
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();

      final post = cups.posts.single;
      expect(post.cafeId, 'kamp');
      expect(post.rating, isNull);
      expect(post.note, isNull);
      expect(
        [for (final i in post.items) (i.kind, i.name, i.hasPhoto)],
        [
          (CupItemKind.coffee, 'Iced Spanish latte', true),
          (CupItemKind.food, 'Banana bread', true),
        ],
      );
      expect(find.text('Cup posted · Marked as Been'), findsOneWidget);
      await _letToastExpire(tester);
    });

    testWidgets('a photo can be left out of the cup', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        _launcher(
          (context) => addPhotosToGallery(
            context,
            deps(
              picker: FakeGalleryPhotoPicker(
                many: [pickedPhoto('a'), pickedPhoto('b')],
              ),
            ),
          ),
        ),
      );
      await _go(tester);
      await tester.tap(find.text('Kamp Craft Coffee'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp(r'^Remove item')), findsNWidgets(2));
      await tester.tap(find.bySemanticsLabel('Remove item 1'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 10'), findsOneWidget);
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();
      expect(cups.posts.single.items, hasLength(1));
      await _letToastExpire(tester);
    });

    testWidgets('a failed post keeps the composer open with Try again', (
      tester,
    ) async {
      usePhone(tester);
      cups.failure = const CupsException(
        "Couldn't upload your photos. Check your connection and try again.",
      );
      await tester.pumpWidget(
        _launcher(
          (context) => addPhotosToGallery(
            context,
            deps(picker: FakeGalleryPhotoPicker(many: [pickedPhoto('a')])),
          ),
        ),
      );
      await _go(tester);
      await tester.tap(find.text('Kamp Craft Coffee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Post cup'));
      await tester.pumpAndSettle();

      expect(find.text('Add your cup'), findsOneWidget);
      expect(
        find.text(
          "Couldn't upload your photos. Check your connection and try again.",
        ),
        findsOneWidget,
      );
      cups.failure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(cups.posts, hasLength(1));
      await _letToastExpire(tester);
    });

    testWidgets('cancelling the photo picker does nothing', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        _launcher(
          (context) => addPhotosToGallery(
            context,
            deps(picker: FakeGalleryPhotoPicker()),
          ),
        ),
      );
      await _go(tester);
      expect(find.text('Which cafe is this from?'), findsNothing);
      expect(cups.posts, isEmpty);
    });
  });

  group('public note', () {
    Future<void> pumpNote(WidgetTester tester, {required bool public}) async {
      final visibility = ProfileVisibilityCubit(
        repository: FakePublicProfileRepository(highlights: public),
      );
      addTearDown(visibility.close);
      await visibility.load();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: visibility,
            child: const Scaffold(body: GalleryPublicNote()),
          ),
        ),
      );
    }

    testWidgets('says notes are public', (tester) async {
      await pumpNote(tester, public: true);
      expect(
        find.text(
          'Notes are public on your profile. Keep opinions about the whole '
          'cafe for your cup’s note.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('with the gallery switched off, says it is hidden', (
      tester,
    ) async {
      await pumpNote(tester, public: false);
      expect(find.textContaining('Your cups are hidden'), findsOneWidget);
      expect(find.textContaining('are public'), findsNothing);
    });
  });
}
