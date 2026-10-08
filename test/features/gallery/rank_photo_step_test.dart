import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_ranking_flow.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/gallery_flows.dart';
import 'package:nook/injection_container.dart';

import '../lists/lists_fixtures.dart';
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
  });

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
    await reveal(
      tester,
      deps: galleryDeps(cubit: gallery, picker: picker),
    );
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

  testWidgets('library → add sheet with the cafe fixed → added in place', (
    tester,
  ) async {
    final results = await reveal(
      tester,
      deps: galleryDeps(cubit: gallery, picker: picker),
    );
    await tester.tap(find.text('Add a photo of what you had'));
    await tester.pumpAndSettle();
    expect(find.text('Take a photo'), findsOneWidget);
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();

    expect(picker.libraryCalls, 1);
    expect(find.text('Add to your gallery'), findsOneWidget);
    // Fixed: the cafe was just ranked, so there is nothing to change.
    expect(find.bySemanticsLabel('Cafe: Tadaima'), findsOneWidget);
    expect(find.text('Change'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Drink (optional)'),
      'Matcha latte',
    );
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();

    expect(repo.added.single, (
      cafeId: 'a',
      count: 1,
      source: GalleryPhotoSource.rank,
      drink: 'Matcha latte',
      caption: null,
    ));
    // Back on the reveal, which now says it worked.
    expect(find.text('Added to your gallery'), findsOneWidget);
    expect(find.text('Add a photo of what you had'), findsNothing);
    expect(
      analytics.events,
      containsAll(['rank_photo_tapped', 'rank_photo_added']),
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(results, [RankingFlowOutcome.completed]);
  });

  testWidgets('the camera works the same way', (tester) async {
    await reveal(
      tester,
      deps: galleryDeps(cubit: gallery, picker: picker),
    );
    await tester.tap(find.text('Add a photo of what you had'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(picker.cameraCalls, 1);
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    expect(repo.added.single.source, GalleryPhotoSource.rank);
  });

  testWidgets('backing out of the photo leaves the reveal as it was', (
    tester,
  ) async {
    picker.one = null; // The system picker was cancelled.
    await reveal(
      tester,
      deps: galleryDeps(cubit: gallery, picker: picker),
    );
    await tester.tap(find.text('Add a photo of what you had'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from library'));
    await tester.pumpAndSettle();
    expect(find.text('Add a photo of what you had'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });
}
