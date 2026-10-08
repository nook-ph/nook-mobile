import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/gallery_flows.dart';
import 'package:nook/features/gallery/presentation/widgets/cafe_picker_sheet.dart';
import 'package:nook/utils/theme/theme.dart';

import '../lists/lists_fixtures.dart' show usePhone;
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
    testWidgets('pick, choose the cafe, add with a drink', (tester) async {
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
          (context) => addPhotosToGallery(
            context,
            galleryDeps(cubit: cubit, picker: picker, cafes: cafes),
          ),
        ),
      );
      await _go(tester);

      // The located photo suggested Lorenzo's.
      expect(cafes.takenAtCalls, [(10.33, 123.9)]);
      expect(find.text('Which cafe are these from?'), findsOneWidget);
      expect(find.text('Taken here?'), findsOneWidget);
      await tester.tap(find.text('Kamp Craft Coffee'));
      await tester.pumpAndSettle();

      expect(find.text('Add 2 photos'), findsNWidgets(2)); // title + button
      expect(find.text('Drink (optional)'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Drink (optional)'),
        'Iced Spanish latte',
      );

      // Change the cafe from the add sheet.
      await tester.tap(
        find.bySemanticsLabel('Cafe: Kamp Craft Coffee. Change'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("Lorenzo's Cafe").last);
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel("Cafe: Lorenzo's Cafe. Change"),
        findsOneWidget,
      );

      await tester.tap(find.text('Add 2 photos').last);
      await tester.pumpAndSettle();

      expect(repo.added.single, (
        cafeId: 'lorenzo',
        count: 2,
        source: GalleryPhotoSource.gallery,
        drink: 'Iced Spanish latte',
        caption: null,
      ));
      expect(cubit.state.photos, hasLength(2));
      expect(find.text('2 photos added'), findsOneWidget);
      await _letToastExpire(tester);
    });

    testWidgets('a note typed in the add sheet is sent as the caption', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(
        _launcher(
          (context) => addPhotosToGallery(
            context,
            galleryDeps(
              cubit: cubit,
              picker: FakeGalleryPhotoPicker(many: [pickedPhoto('a')]),
              cafes: FakeCafePickerSource(been: [kamp], near: const []),
            ),
          ),
        ),
      );
      await _go(tester);
      await tester.tap(find.text('Kamp Craft Coffee'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Say something about it (optional)'),
        'Best cortado in town',
      );
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      expect(repo.added.single.caption, 'Best cortado in town');
      expect(repo.added.single.drink, isNull);
      await _letToastExpire(tester);
    });

    testWidgets('a photo can be left out of the batch', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        _launcher(
          (context) => addPhotosToGallery(
            context,
            galleryDeps(
              cubit: cubit,
              picker: FakeGalleryPhotoPicker(
                many: [pickedPhoto('a'), pickedPhoto('b')],
              ),
              cafes: FakeCafePickerSource(been: [kamp], near: const []),
            ),
          ),
        ),
      );
      await _go(tester);
      await tester.tap(find.text('Kamp Craft Coffee'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Remove this photo'), findsNWidgets(2));
      await tester.tap(find.bySemanticsLabel('Remove this photo').first);
      await tester.pumpAndSettle();
      expect(find.text('Add to your gallery'), findsOneWidget);
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      expect(repo.added.single.count, 1);
      expect(repo.added.single.drink, isNull);
      await _letToastExpire(tester);
    });

    testWidgets('a failed upload keeps the sheet and offers Try again', (
      tester,
    ) async {
      usePhone(tester);
      repo.writeFailure = Exception('offline');
      await tester.pumpWidget(
        _launcher(
          (context) => addPhotosToGallery(
            context,
            galleryDeps(
              cubit: cubit,
              picker: FakeGalleryPhotoPicker(many: [pickedPhoto('a')]),
              cafes: FakeCafePickerSource(been: [kamp], near: const []),
            ),
          ),
        ),
      );
      await _go(tester);
      await tester.tap(find.text('Kamp Craft Coffee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();

      expect(find.textContaining("Couldn't add the photo"), findsOneWidget);
      repo.writeFailure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Add to your gallery'), findsNothing);
      expect(cubit.state.photos, hasLength(1));
      await _letToastExpire(tester);
    });

    testWidgets('cancelling the photo picker does nothing', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(
        _launcher(
          (context) => addPhotosToGallery(
            context,
            galleryDeps(cubit: cubit, picker: FakeGalleryPhotoPicker()),
          ),
        ),
      );
      await _go(tester);
      expect(find.text('Which cafe is this from?'), findsNothing);
      expect(repo.calls, isEmpty);
    });
  });
}
