import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_ranking_flow.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/gallery_flows.dart';
import 'package:nook/injection_container.dart';

import '../lists/lists_fixtures.dart';
import '../cups/cups_fakes.dart';
import 'gallery_fakes.dart';

class _Analytics extends AnalyticsService {
  final events = <String>[];

  @override
  Future<void> track(
    String cafeId,
    String eventType, {
    Map<String, dynamic>? metadata,
  }) async => events.add(eventType);
}

void main() {
  late FakeRankingRepository rankings;
  late CafeRankingCubit ranking;
  late FakeGalleryRepository repo;
  late GalleryCubit gallery;
  late FakeGalleryPhotoPicker picker;
  late _Analytics analytics;
  late FakeCupsRepository cups;

  setUp(() async {
    await sl.reset();
    analytics = _Analytics();
    rankings = FakeRankingRepository();
    sl.registerSingleton<AnalyticsService>(analytics);
    sl.registerSingleton<ICafeRepository>(rankings);
    ranking = rankingCubit(rankings);
    repo = FakeGalleryRepository();
    gallery = GalleryCubit(repository: repo);
    picker = FakeGalleryPhotoPicker(one: pickedPhoto('cup'));
    cups = FakeCupsRepository();
  });

  GalleryFlowDeps deps() => GalleryFlowDeps(
    cubit: gallery,
    picker: picker,
    cafes: FakeCafePickerSource(),
    cups: cups,
  );

  tearDown(() async {
    await ranking.close();
    await gallery.close();
    await sl.reset();
  });

  /// Opens the flow and ranks the first cafe, which goes straight to the
  /// reveal (nothing to compare against).
  Future<List<RankingFlowOutcome?>> reveal(
    WidgetTester tester, {
    GalleryFlowDeps? deps,
  }) async {
    usePhone(tester);
    final results = <RankingFlowOutcome?>[];
    await tester.pumpWidget(
      SheetOpener<RankingFlowOutcome>(
        sheet: CafeRankingFlow(
          cubit: ranking,
          cafeId: 'a',
          cafeName: 'Tadaima',
          cafeLocation: 'Lahug, Cebu City',
          gallery: deps,
        ),
        onResult: results.add,
      ),
    );
    await openSheet(tester);
    await tester.tap(find.text('Liked it'));
    await tester.pumpAndSettle();
    expect(find.text('Your first ranked cafe'), findsOneWidget);
    return results;
  }

  testWidgets('the reveal offers an optional photo, under the score', (
    tester,
  ) async {
    await reveal(tester, deps: deps());
    expect(find.text('Add a photo of what you had'), findsOneWidget);
    expect(find.text('Optional · it goes on your profile'), findsOneWidget);
    // The two buttons and Done are unchanged.
    expect(find.text('View my list'), findsOneWidget);
    expect(find.text('Add a note'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('without a gallery the reveal is as before', (tester) async {
    await reveal(tester);
    expect(find.text('Add a photo of what you had'), findsNothing);
  });

  testWidgets('library → the cup composer for this cafe → added in place', (
    tester,
  ) async {
    final results = await reveal(tester, deps: deps());
    await tester.tap(find.text('Add a photo of what you had'));
    await tester.pumpAndSettle();
    expect(find.text('Take a photo'), findsOneWidget);
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();

    expect(picker.libraryCalls, 1);
    // A cup for this visit, at the cafe that was just ranked.
    expect(find.text('Add your cup'), findsOneWidget);
    expect(find.text('Tadaima'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextField, 'What is it? (optional)'),
      'Matcha latte',
    );
    await tester.tap(find.bySemanticsLabel('Drink'));
    await tester.tap(find.text('Post cup'));
    await tester.pumpAndSettle();

    final post = cups.posts.single;
    expect(post.cafeId, 'a');
    expect(post.items.single.name, 'Matcha latte');
    expect(post.items.single.kind, CupItemKind.drink);
    expect(post.items.single.hasPhoto, isTrue);
    // Back on the reveal, which now says it worked.
    expect(find.text('Added to your cups'), findsOneWidget);
    expect(find.text('Add a photo of what you had'), findsNothing);
    expect(
      analytics.events,
      containsAll(['rank_photo_tapped', 'rank_photo_added']),
    );

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(results, [RankingFlowOutcome.completed]);
  });

  testWidgets('the camera works the same way', (tester) async {
    await reveal(tester, deps: deps());
    await tester.tap(find.text('Add a photo of what you had'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(picker.cameraCalls, 1);
    // Nothing is Coffee until picked.
    await tester.tap(find.bySemanticsLabel('Coffee'));
    await tester.tap(find.text('Post cup'));
    await tester.pumpAndSettle();
    expect(cups.posts, hasLength(1));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('backing out of the photo leaves the reveal as it was', (
    tester,
  ) async {
    picker.one = null; // The system picker was cancelled.
    await reveal(tester, deps: deps());
    await tester.tap(find.text('Add a photo of what you had'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();
    expect(find.text('Add a photo of what you had'), findsOneWidget);
    expect(cups.posts, isEmpty);
  });
}
