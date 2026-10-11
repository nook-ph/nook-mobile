import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_photos_page.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_community_photos_section.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/domain/i_community_photos_repository.dart';
import 'package:nook/features/gallery/presentation/cubit/cafe_photos_cubit.dart';
import 'package:nook/features/gallery/domain/entities/cafe_story.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/presentation/stories/cafe_story_viewer_page.dart';
import 'package:nook/features/gallery/presentation/stories/story_seen_cubit.dart';
import 'package:nook/injection_container.dart';
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
  late List<PickedCafe> added;
  late StorySeenCubit seen;

  setUp(() => added = []);

  Future<CafePhotosCubit> pump(
    WidgetTester tester,
    FakeCommunityPhotosRepository repo, {
    bool been = false,
    bool load = true,
    Set<String> seenIds = const {},
  }) async {
    usePhone(tester);
    final statusRepo = _Statuses({if (been) 'cafe-1': CafeStatus.been});
    final statuses = CafeStatusCubit(
      getCafeStatusesUseCase: GetCafeStatusesUseCase(statusRepo),
      setCafeStatusUseCase: SetCafeStatusUseCase(statusRepo),
    );
    await statuses.loadFor(['cafe-1']);
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
                addPhoto: (_, cafe) async {
                  added.add(cafe);
                  return true;
                },
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

  testWidgets('no photos and been: asks for the first one', (tester) async {
    final cubit = await pump(
      tester,
      FakeCommunityPhotosRepository(),
      been: true,
    );

    expect(find.text('No cups yet'), findsOneWidget);
    expect(find.text('See all'), findsNothing);

    await tester.tap(find.text('Add your cup'));
    await tester.pump();
    expect(added.single.id, 'cafe-1');
    expect(added.single.name, 'Kamp Craft Coffee');
    // Reloaded after the add.
    expect(cubit.state.status, CafePhotosStatus.loaded);
  });

  testWidgets('one photo: one ring, no See all', (tester) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([
        communityPhoto('p1', username: 'sai', drink: 'Spanish latte'),
      ]),
    );

    expect(find.text('Latest cups'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('@sai'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(r'^@sai’s 1 cup, .*, new\. Open$')),
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
    expect(find.textContaining('2 cups'), findsOneWidget);
    // Newest person first.
    final sai = tester.getTopLeft(find.text('@sai')).dx;
    final lia = tester.getTopLeft(find.text('@lia')).dx;
    expect(sai, lessThan(lia));
  });

  testWidgets('seen people read as seen', (tester) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([communityPhoto('p1', username: 'sai')]),
      seenIds: {'p1'},
    );

    expect(
      find.bySemanticsLabel(RegExp(r'^@sai’s 1 cup, [^,]*\. Open$')),
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
    expect(added.single.id, 'cafe-1');
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

  testWidgets('many photos: See all opens the grid', (tester) async {
    final repo = FakeCommunityPhotosRepository([
      for (var i = 0; i < 12; i++) communityPhoto('p$i', username: 'u$i'),
    ]);
    // The grid builds its own cubit.
    sl.registerSingleton<ICommunityPhotosRepository>(repo);
    addTearDown(() => sl.unregister<ICommunityPhotosRepository>());
    await pump(tester, repo);

    expect(find.text('12'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    // Only a tray's worth is loaded.
    expect(find.text('@u7'), findsOneWidget);
    expect(find.text('@u8'), findsNothing);

    await tester.tap(find.text('See all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CafePhotosPage), findsOneWidget);
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
      find.bySemanticsLabel(RegExp(r'^@lia’s 1 cup, [^,]*\. Open$')),
      findsOneWidget,
    );
  });
}
