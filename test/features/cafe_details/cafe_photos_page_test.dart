import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_photos_page.dart';
import 'package:nook/features/gallery/presentation/cubit/cafe_photos_cubit.dart';
import 'package:nook/utils/theme/theme.dart';

import '../gallery/community_photos_fakes.dart';
import '../lists/lists_fixtures.dart' show usePhone;

void main() {
  Future<CafePhotosCubit> pump(
    WidgetTester tester,
    FakeCommunityPhotosRepository repo, {
    int pageSize = 4,
  }) async {
    usePhone(tester);
    final cubit = CafePhotosCubit(
      repository: repo,
      cafeId: 'cafe-1',
      pageSize: pageSize,
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: CafePhotosPage(
          cafeId: 'cafe-1',
          cafeName: 'Kamp Craft Coffee',
          cubit: cubit,
        ),
      ),
    );
    return cubit;
  }

  testWidgets('loading shows the grid skeleton', (tester) async {
    await pump(tester, FakeCommunityPhotosRepository());
    expect(find.bySemanticsLabel('Loading community photos'), findsOneWidget);
    expect(find.text('Community photos'), findsOneWidget);
    expect(find.text('Kamp Craft Coffee'), findsOneWidget);
  });

  testWidgets('a failed first load offers Try again', (tester) async {
    final repo = FakeCommunityPhotosRepository([communityPhoto('p1')])
      ..failure = offline;
    final cubit = await pump(tester, repo);
    await cubit.load();
    await tester.pump();

    expect(find.text('Try again'), findsOneWidget);

    repo.failure = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('@sai'), findsOneWidget);
  });

  testWidgets('pages on as it scrolls, then says it has them all', (
    tester,
  ) async {
    final repo = FakeCommunityPhotosRepository([
      for (var i = 0; i < 10; i++) communityPhoto('p$i', username: 'u$i'),
    ]);
    final cubit = await pump(tester, repo);
    await cubit.load();
    await tester.pump();
    expect(find.text('@u0'), findsOneWidget);

    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      await tester.pump();
    }
    expect(cubit.state.photos, hasLength(10));
    expect(cubit.state.hasMore, isFalse);
    expect(find.text('That’s every photo so far.'), findsOneWidget);
  });

  testWidgets('a failed next page keeps the photos and offers Try again', (
    tester,
  ) async {
    final repo = FakeCommunityPhotosRepository([
      for (var i = 0; i < 10; i++) communityPhoto('p$i', username: 'u$i'),
    ]);
    final cubit = await pump(tester, repo);
    await cubit.load();
    repo.failure = offline;
    await cubit.loadMore();
    await tester.pump();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pump();

    expect(find.text('Couldn’t load more photos.'), findsOneWidget);
    expect(cubit.state.photos, hasLength(4));
  });
}
