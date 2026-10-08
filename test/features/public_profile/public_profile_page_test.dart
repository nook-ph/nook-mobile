import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/widgets/profile_gallery_tab.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';
import 'package:nook/features/public_profile/presentation/pages/public_profile_page.dart';

import '../../core/analytics/recording_analytics.dart';
import '../gallery/gallery_fakes.dart' show FakeGalleryRepository;
import 'public_profile_fakes.dart';

void main() {
  late List<({String username, String name, bool own})> shared;
  late List<String> opened;
  late RecordingAnalytics analytics;

  setUp(() {
    shared = [];
    opened = [];
    analytics = RecordingAnalytics.install(addTearDown);
  });

  Future<FakePublicProfileRepository> pump(
    WidgetTester tester, {
    FakePublicProfileRepository? repository,
    bool preview = false,
    bool signedIn = true,
    FakeBlocks? blocks,
  }) async {
    final repo = repository ?? FakePublicProfileRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<GalleryCubit>(
              create: (_) => GalleryCubit(repository: FakeGalleryRepository()),
            ),
            BlocProvider<BlockCubit>.value(value: blocks ?? FakeBlocks()),
          ],
          child: PublicProfilePage(
            isSignedIn: () => signedIn,
            userId: 'bea-id',
            nameHint: 'Bea Santos',
            preview: preview,
            repository: repo,
            onOpenCafe: opened.add,
            shareProfile:
                ({required username, required name, own = false}) async =>
                    shared.add((username: username, name: name, own: own)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return repo;
  }

  testWidgets('a visitor sees the stat row, Gallery and Reviews; no Ranked '
      'tab, no Top 3 and no score', (tester) async {
    final repo = await pump(
      tester,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );

    expect(repo.asked.single.userId, 'bea-id');
    expect(find.text('@beasantos'), findsOneWidget);
    expect(find.text('Bea Santos'), findsOneWidget);
    // Number over label; the old counts line is gone.
    expect(find.bySemanticsLabel('18 Ranked'), findsOneWidget);
    expect(find.bySemanticsLabel('2 Reviews'), findsOneWidget);
    expect(find.bySemanticsLabel('2 Cups'), findsOneWidget);
    expect(find.text('18 cafes ranked · 2 reviews · 2 cups'), findsNothing);
    expect(find.text('Flat whites and window seats.'), findsOneWidget);
    // There is no Top 3 strip: the ranking is private.
    expect(find.text('Top cafes'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Number \d')), findsNothing);
    expect(find.text('Gallery'), findsOneWidget);
    // "Reviews" is the stat label and the tab.
    expect(find.text('Reviews'), findsNWidgets(2));
    // No count badges on the tabs, and no gallery counts line.
    expect(find.text('2 cups · 2 cafes'), findsNothing);

    // Nothing private: no Ranked tab (the stat label is the only "Ranked"),
    // no Lists tab, no Edit, no score.
    expect(find.text('Ranked'), findsOneWidget);
    expect(find.text('Lists'), findsNothing);
    expect(find.text('Edit profile'), findsNothing);
    expect(find.textContaining(RegExp(r'\d+\.\d')), findsNothing);
    expect(find.textContaining('out of 10'), findsNothing);
  });

  testWidgets('Ranked and Cups are left off the stat row when the owner '
      'hides them', (tester) async {
    await pump(
      tester,
      repository: FakePublicProfileRepository(
        profile: beaProfile(highlightsPublic: false),
      ),
    );
    expect(find.text('Ranked'), findsNothing);
    expect(find.text('Cups'), findsNothing);
    expect(find.bySemanticsLabel('2 Reviews'), findsOneWidget);
  });

  testWidgets('nothing ranked: no Top 3, Gallery stays', (tester) async {
    await pump(
      tester,
      repository: FakePublicProfileRepository(profile: beaProfile(ranked: 0)),
    );
    expect(find.text('Top cafes'), findsNothing);
    expect(find.text('Gallery'), findsOneWidget);
  });

  testWidgets('switch off: no gallery, a private note, reviews still shown', (
    tester,
  ) async {
    await pump(
      tester,
      repository: FakePublicProfileRepository(
        profile: beaProfile(highlightsPublic: false),
      ),
    );
    expect(find.text('Top cafes'), findsNothing);
    expect(find.text('Gallery'), findsNothing);
    expect(
      find.text('Their gallery is private. Their reviews are public.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('2 Reviews'), findsOneWidget);
    expect(find.text('Tadaima'), findsOneWidget);
    expect(find.text('Pulso'), findsOneWidget);
  });

  testWidgets('a signed-in visitor reports a photo, choosing a reason', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );
    await tester.tap(find.byType(GalleryTile).first);
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Photo options'));
    await tester.pumpAndSettle();
    expect(find.text('Report this photo?'), findsOneWidget);
    await tester.tap(find.text(PhotoReportReason.spam.label));
    await tester.pumpAndSettle();

    expect(repo.reports, [('p1', PhotoReportReason.spam)]);
    expect(find.text('Thanks. We’ll take a look.'), findsOneWidget);
    expect(analytics.propertiesOf('photo_reported'), {'reason': 'spam'});
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('a guest cannot report a photo', (tester) async {
    await pump(
      tester,
      signedIn: false,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );
    await tester.tap(find.byType(GalleryTile).first);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Photo options'), findsNothing);
  });

  testWidgets('an unknown or hidden profile says it is not available', (
    tester,
  ) async {
    await pump(tester, repository: FakePublicProfileRepository());
    expect(find.text('This profile isn’t available'), findsOneWidget);
  });

  testWidgets('a failed read offers Retry, which reads again', (tester) async {
    final repo = FakePublicProfileRepository(profile: beaProfile())
      ..failure = Exception('offline');
    await pump(tester, repository: repo);
    expect(find.text('Could not load this profile'), findsOneWidget);

    repo.failure = null;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Bea Santos'), findsOneWidget);
  });

  testWidgets('Share shares the profile’s link', (tester) async {
    await pump(
      tester,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );
    await tester.tap(find.bySemanticsLabel('Share profile'));
    expect(shared.single.username, 'beasantos');
    expect(shared.single.own, isFalse);
  });

  testWidgets('the owner’s preview is titled Preview, without Share', (
    tester,
  ) async {
    await pump(
      tester,
      preview: true,
      repository: FakePublicProfileRepository(
        profile: beaProfile(isSelf: true),
      ),
    );
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('What visitors see on your profile'), findsOneWidget);
    expect(find.bySemanticsLabel('Share profile'), findsNothing);
    expect(find.text('Top cafes'), findsNothing);
  });

  // The Preview bar carries a subtitle; at large text the fixed 56pt bar
  // overflowed (about 28pt at 2.0).
  testWidgets('the preview bar grows with large text instead of overflowing', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(
      tester,
      preview: true,
      repository: FakePublicProfileRepository(
        profile: beaProfile(isSelf: true),
      ),
    );
    final bar = tester.getRect(find.byType(ProfileNavBar));
    final title = tester.getRect(find.text('Preview'));
    final subtitle = tester.getRect(
      find.text('What visitors see on your profile'),
    );
    expect(title.top, greaterThanOrEqualTo(bar.top));
    expect(subtitle.bottom, lessThanOrEqualTo(bar.bottom));
  });

  testWidgets('a loaded profile is logged as one view, with where from', (
    tester,
  ) async {
    await pump(
      tester,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );
    await tester.pump();
    expect(analytics.names, ['public_profile_viewed']);
    expect(analytics.propertiesOf('public_profile_viewed'), {
      'source': 'link',
      'is_self': false,
      'highlights_public': true,
    });
  });

  testWidgets('the owner’s preview is logged as a preview', (tester) async {
    await pump(
      tester,
      preview: true,
      repository: FakePublicProfileRepository(
        profile: beaProfile(isSelf: true),
      ),
    );
    expect(
      analytics.propertiesOf('public_profile_viewed')?['source'],
      'preview',
    );
  });

  testWidgets('a review’s cafe opens the cafe', (tester) async {
    await pump(
      tester,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );
    // The tab, not the stat above it.
    await tester.tap(find.text('Reviews').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tadaima').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tadaima').last);
    expect(opened, ['cafe-r1']);
  });

  testWidgets('signed in: Block asks, blocks and leaves the profile', (
    tester,
  ) async {
    final blocks = FakeBlocks();
    await pump(
      tester,
      blocks: blocks,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block @beasantos'));
    await tester.pumpAndSettle();
    expect(find.text('Block @beasantos?'), findsOneWidget);
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(blocks.blocked, ['bea-id']);
    expect(analytics.propertiesOf('user_blocked'), {'from': 'profile'});
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('a guest has no Block', (tester) async {
    await pump(
      tester,
      signedIn: false,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );
    expect(find.byTooltip('More'), findsNothing);
  });
}

/// Records blocks.
class FakeBlocks extends Cubit<Set<String>> implements BlockCubit {
  FakeBlocks() : super(const {});

  final List<String> blocked = [];

  @override
  Future<void> block(String userId) async => blocked.add(userId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
