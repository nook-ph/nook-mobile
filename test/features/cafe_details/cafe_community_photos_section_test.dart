import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_community_photos_section.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/presentation/cubit/cafe_photos_cubit.dart';
import 'package:nook/features/gallery/domain/entities/cafe_story.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/presentation/stories/cafe_story_viewer_page.dart';
import 'package:nook/features/gallery/presentation/stories/story_seen_cubit.dart';
import 'package:nook/utils/theme/theme.dart';

import '../gallery/community_photos_fakes.dart';
import '../lists/lists_fixtures.dart' show usePhone;

class _Statuses implements ICafeRepository {
  _Statuses(this.server);

  final Map<String, CafeStatus> server;

  @override
  Future<Map<String, CafeStatus>> getCafeStatuses(List<String> ids) async => {
    for (final id in ids)
      if (server[id] != null) id: server[id]!,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// A repository whose first read waits for [gate].
class _Slow extends FakeCommunityPhotosRepository {
  _Slow(super.photos);

  final gate = Completer<void>();

  @override
  Future<CommunityPhotoPage> getCafePhotos(
    String cafeId, {
    required int limit,
    int offset = 0,
  }) async {
    await gate.future;
    return super.getCafePhotos(cafeId, limit: limit, offset: offset);
  }
}

void main() {
  late int addTaps;
  late List<CafePhotosState> seeAll;
  late StorySeenCubit seen;

  setUp(() {
    addTaps = 0;
    seeAll = [];
  });

  Future<CafePhotosCubit> pump(
    WidgetTester tester,
    FakeCommunityPhotosRepository repo, {
    bool been = false,
    bool guestBeen = false,
    bool load = true,
    Set<String> seenIds = const {},
    int? cupCount,
  }) async {
    usePhone(tester);
    final statusRepo = _Statuses({if (been) 'cafe-1': CafeStatus.been});
    final statuses = CafeStatusCubit(
      getCafeStatusesUseCase: GetCafeStatusesUseCase(statusRepo),
      setCafeStatusUseCase: SetCafeStatusUseCase(statusRepo),
    );
    await statuses.loadFor(['cafe-1']);
    if (guestBeen) statuses.showLocal({'cafe-1': CafeStatus.been});
    final cubit = CafePhotosCubit(
      repository: repo,
      cafeId: 'cafe-1',
      pageSize: CafePhotosCubit.stripPageSize,
    );
    if (load) unawaited(cubit.load());
    seen = StorySeenCubit(store: MemoryStorySeenStore(seenIds));
    await seen.load();
    addTearDown(seen.close);
    addTearDown(cubit.close);
    addTearDown(statuses.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: BlocProvider.value(
          value: statuses,
          child: Scaffold(
            body: SingleChildScrollView(
              child: CafeCommunityPhotosSection(
                cafeId: 'cafe-1',
                cafeName: 'Kamp Craft Coffee',
                cubit: cubit,
                seen: seen,
                reviewOf: (id) => id == 'review-1'
                    ? const StoryReview(
                        rating: 4,
                        text: 'Silky, not too sweet.',
                      )
                    : null,
                cupCount: cupCount,
                onAdd: () => addTaps++,
                onSeeAll: seeAll.add,
              ),
            ),
          ),
        ),
      ),
    );
    // The skeleton pulses forever, so no pumpAndSettle.
    await tester.pump();
    await tester.pump();
    return cubit;
  }

  testWidgets('shows a skeleton, not a spinner, while loading', (tester) async {
    final repo = _Slow([communityPhoto('p1')]);
    await pump(tester, repo);

    expect(find.bySemanticsLabel('Loading latest cups'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Latest cups'), findsNothing);

    repo.gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Latest cups'), findsOneWidget);
  });

  testWidgets('a failed load leaves the page quietly', (tester) async {
    final repo = FakeCommunityPhotosRepository()..failure = offline;
    await pump(tester, repo, been: true);

    expect(find.text('Latest cups'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('no photos and not been: nothing at all', (tester) async {
    await pump(tester, FakeCommunityPhotosRepository());

    expect(find.text('Latest cups'), findsNothing);
    expect(find.text('No cups yet'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('no photos and been: still nothing (the Cups section asks '
      'for the first cup)', (tester) async {
    await pump(tester, FakeCommunityPhotosRepository(), been: true);

    expect(find.text('Latest cups'), findsNothing);
    expect(find.text('No cups yet'), findsNothing);
    expect(find.text('Add your cup'), findsNothing);
  });

  testWidgets('one photo: one ring, no Photos link', (tester) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([
        communityPhoto('p1', username: 'sai', drink: 'Spanish latte'),
      ]),
    );

    expect(find.text('Latest cups'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('@sai'), findsOneWidget);
    expect(find.bySemanticsLabel('See all photos'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'^@sai’s 1 photo, .*, new\. Open$')),
      findsOneWidget,
    );
    // No add slot for someone who hasn't been.
    expect(find.text('Add your cup'), findsNothing);
  });

  testWidgets('a person with several photos is one ring', (tester) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([
        communityPhoto('p3', username: 'sai', takenAt: DateTime(2026, 3, 3)),
        communityPhoto('p2', username: 'lia', takenAt: DateTime(2026, 3, 2)),
        communityPhoto('p1', username: 'sai', takenAt: DateTime(2026, 3, 1)),
      ]),
    );

    expect(find.text('@sai'), findsOneWidget);
    expect(find.text('@lia'), findsOneWidget);
    // Two days, two visits: two cups by sai, one by lia.
    expect(find.text('2 visits'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d cups')), findsNothing);
    // Newest person first.
    final sai = tester.getTopLeft(find.text('@sai')).dx;
    final lia = tester.getTopLeft(find.text('@lia')).dx;
    expect(sai, lessThan(lia));
  });

  testWidgets('one visit with three photos is one cup, "3 photos" '
      '(not "3 cups")', (tester) async {
    final day = DateTime(2026, 10, 2, 15);
    await pump(
      tester,
      FakeCommunityPhotosRepository([
        for (var i = 0; i < 3; i++)
          communityPhoto(
            'p$i',
            username: 'kuroba_kohii',
            takenAt: day.add(Duration(minutes: i)),
          ),
      ]),
    );

    expect(find.text('Latest cups'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3 photos'), findsOneWidget);
    expect(find.textContaining('3 cups'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'^@kuroba_kohii’s 3 photos, ')),
      findsOneWidget,
    );
  });

  testWidgets('the title counts the cafe’s cups when the page knows them', (
    tester,
  ) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([communityPhoto('p1', username: 'sai')]),
      cupCount: 5,
    );

    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('seen people read as seen', (tester) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([communityPhoto('p1', username: 'sai')]),
      seenIds: {'p1'},
    );

    expect(
      find.bySemanticsLabel(RegExp(r'^@sai’s 1 photo, [^,]*\. Open$')),
      findsOneWidget,
    );
  });

  testWidgets('been with no cup of your own: Add your cup comes first', (
    tester,
  ) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([communityPhoto('p1', username: 'sai')]),
      been: true,
    );

    expect(find.text('Add your cup'), findsOneWidget);
    final addX = tester.getTopLeft(find.text('Add your cup')).dx;
    expect(addX, lessThan(tester.getTopLeft(find.text('@sai')).dx));
    await tester.tap(find.text('Add your cup'));
    await tester.pump();
    expect(addTaps, 1);
  });

  testWidgets('a guest\'s on-phone Been offers no add slot (it needs an '
      'account)', (tester) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([communityPhoto('p1', username: 'sai')]),
      guestBeen: true,
    );

    expect(find.text('@sai'), findsOneWidget);
    expect(find.text('Add your cup'), findsNothing);
  });

  testWidgets('your own cup reads "You", and no add slot', (tester) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([
        communityPhoto('p1', username: 'me', isSelf: true),
      ]),
      been: true,
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.text('@me'), findsNothing);
    expect(find.text('Add your cup'), findsNothing);
  });

  testWidgets('many photos: Photos hands over what the tray loaded', (
    tester,
  ) async {
    final repo = FakeCommunityPhotosRepository([
      for (var i = 0; i < 12; i++) communityPhoto('p$i', username: 'u$i'),
    ]);
    await pump(tester, repo, cupCount: 12);

    expect(find.text('12'), findsOneWidget);
    // Named for where it goes, not a second "See all" (UX review 1.3).
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
    // Only a tray's worth is loaded.
    expect(find.text('@u7'), findsOneWidget);
    expect(find.text('@u8'), findsNothing);

    await tester.tap(find.text('Photos'));
    await tester.pump();
    expect(seeAll.single.photos, hasLength(8));
  });

  testWidgets('a ring opens the story viewer on that person, with the '
      'review under a review photo', (tester) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([
        communityPhoto('p2', username: 'sai', drink: 'Flat white'),
        communityPhoto(
          'p1',
          username: 'lia',
          drink: 'Spanish latte',
          source: GalleryPhotoSource.review,
        ),
      ]),
    );

    await tester.tap(find.text('@lia'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(CafeStoryViewerPage), findsOneWidget);
    expect(find.text('Spanish latte'), findsOneWidget);
    expect(find.text('Silky, not too sweet.'), findsOneWidget);
    expect(find.bySemanticsLabel('Rated 4 out of 5'), findsOneWidget);
    expect(seen.state, contains('p1'));

    // Back on the page, lia's ring is seen.
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.bySemanticsLabel(RegExp(r'^@lia’s 1 photo, [^,]*\. Open$')),
      findsOneWidget,
    );
  });
}
