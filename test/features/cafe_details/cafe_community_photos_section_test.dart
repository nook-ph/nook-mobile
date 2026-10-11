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
import 'package:nook/features/gallery/presentation/pages/gallery_viewer_page.dart';
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

  setUp(() => added = []);

  Future<CafePhotosCubit> pump(
    WidgetTester tester,
    FakeCommunityPhotosRepository repo, {
    bool been = false,
    bool load = true,
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

    expect(find.bySemanticsLabel('Loading community photos'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Community photos'), findsNothing);

    repo.gate.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Community photos'), findsOneWidget);
  });

  testWidgets('a failed load leaves the page quietly', (tester) async {
    final repo = FakeCommunityPhotosRepository()..failure = offline;
    await pump(tester, repo, been: true);

    expect(find.text('Community photos'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('no photos and not been: nothing at all', (tester) async {
    await pump(tester, FakeCommunityPhotosRepository());

    expect(find.text('Community photos'), findsNothing);
    expect(find.text('No photos yet'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('no photos and been: asks for the first one', (tester) async {
    final cubit = await pump(
      tester,
      FakeCommunityPhotosRepository(),
      been: true,
    );

    expect(find.text('No photos yet'), findsOneWidget);
    expect(find.text('See all'), findsNothing);

    await tester.tap(find.text('Add a photo'));
    await tester.pump();
    expect(added.single.id, 'cafe-1');
    expect(added.single.name, 'Kamp Craft Coffee');
    // Reloaded after the add.
    expect(cubit.state.status, CafePhotosStatus.loaded);
  });

  testWidgets('one photo: credited, no See all', (tester) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([
        communityPhoto('p1', username: 'sai', drink: 'Spanish latte'),
      ]),
    );

    expect(find.text('Community photos'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Spanish latte'), findsOneWidget);
    expect(find.text('@sai'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
    expect(find.bySemanticsLabel('Open @sai’s profile'), findsOneWidget);
  });

  testWidgets('many photos: See all in the header and at the strip end', (
    tester,
  ) async {
    final repo = FakeCommunityPhotosRepository([
      for (var i = 0; i < 12; i++) communityPhoto('p$i', username: 'u$i'),
    ]);
    // The grid builds its own cubit.
    sl.registerSingleton<ICommunityPhotosRepository>(repo);
    addTearDown(() => sl.unregister<ICommunityPhotosRepository>());
    await pump(tester, repo);

    expect(find.text('12'), findsOneWidget);
    expect(find.text('See all'), findsNWidgets(2));
    expect(find.text('12 photos'), findsOneWidget);
    // Only a strip's worth is loaded.
    expect(find.text('@u7'), findsOneWidget);
    expect(find.text('@u8'), findsNothing);

    await tester.tap(find.text('See all').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CafePhotosPage), findsOneWidget);
  });

  testWidgets('your own photo reads "You" and is not a link', (tester) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([
        communityPhoto('p1', username: 'me', isSelf: true),
      ]),
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.text('@me'), findsNothing);
    expect(find.bySemanticsLabel('Added by you'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('profile')), findsNothing);
  });

  testWidgets('a photo opens the viewer with its credit, not a cafe chip', (
    tester,
  ) async {
    await pump(
      tester,
      FakeCommunityPhotosRepository([
        // Same date: newest id first, as the server sends them.
        communityPhoto('p2', username: 'sai'),
        communityPhoto('p1', username: 'lia'),
      ]),
    );

    await tester.tap(find.bySemanticsLabel(RegExp(r'@lia\. Open photo')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(GalleryViewerPage), findsOneWidget);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Open @lia’s profile'), findsWidgets);
    expect(find.bySemanticsLabel('Open Kamp Craft Coffee'), findsNothing);
  });
}
