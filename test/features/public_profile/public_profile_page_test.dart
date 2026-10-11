import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_actions_sheet.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/cups/presentation/widgets/profile_cups_grid.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/features/public_profile/domain/entities/public_profile.dart';
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

  testWidgets('a visitor sees the stat row and one Cups grid; no tabs, no '
      'Top 3 and no score', (tester) async {
    final repo = await pump(
      tester,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );

    expect(repo.asked.single.userId, 'bea-id');
    expect(find.text('@beasantos'), findsOneWidget);
    expect(find.text('Bea Santos'), findsOneWidget);
    // Two reviews and two photos at four cafes: four cups (visits).
    expect(find.bySemanticsLabel('18 Ranked'), findsOneWidget);
    expect(find.bySemanticsLabel('4 Cups'), findsOneWidget);
    expect(find.bySemanticsLabel('4 Cafes'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Reviews')), findsNothing);
    expect(find.text('4 cups · 4 cafes · 2 photos'), findsOneWidget);
    expect(find.text('Flat whites and window seats.'), findsOneWidget);
    // There is no Top 3 strip: the ranking is private.
    expect(find.text('Top cafes'), findsNothing);
    // One grid: no Reviews tab, no Lists tab, no Edit, no score.
    expect(find.byTooltip('Reviews'), findsNothing);
    expect(find.byTooltip('Lists'), findsNothing);
    expect(find.text('Edit profile'), findsNothing);
    expect(find.textContaining('out of 10'), findsNothing);
    expect(find.byType(ProfileCupTile), findsNWidgets(4));
  });

  testWidgets('Ranked is left off the stat row when the owner hides it', (
    tester,
  ) async {
    await pump(
      tester,
      repository: FakePublicProfileRepository(
        profile: beaProfile(highlightsPublic: false),
      ),
    );
    expect(find.text('Ranked'), findsNothing);
    expect(find.bySemanticsLabel('2 Cups'), findsOneWidget);
  });

  testWidgets('switch off: a private note, cups with notes still shown', (
    tester,
  ) async {
    await pump(
      tester,
      repository: FakePublicProfileRepository(
        profile: beaProfile(highlightsPublic: false),
      ),
    );
    expect(find.text('Top cafes'), findsNothing);
    expect(
      find.text('Their photos are private. Their notes and stars are public.'),
      findsWidgets,
    );
    expect(find.text('Tadaima'), findsOneWidget);
    expect(find.text('Pulso'), findsOneWidget);
    expect(find.text('Kamp Craft Coffee'), findsNothing);
  });

  testWidgets('a tile opens that cafe’s cups, and the cafe from there', (
    tester,
  ) async {
    await pump(
      tester,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );
    await tester.ensureVisible(find.text('Tadaima'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tadaima'));
    await tester.pumpAndSettle();
    expect(find.text('1 visit'), findsOneWidget);
    expect(find.text('Quiet upstairs, good Wi-Fi.'), findsWidgets);
    expect(find.bySemanticsLabel('4 out of 5 stars'), findsWidgets);

    await tester.tap(find.bySemanticsLabel('Open Tadaima'));
    await tester.pumpAndSettle();
    expect(opened, ['cafe-r1']);
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
    await tester.tap(find.bySemanticsLabel('Profile options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share profile'));
    await tester.pumpAndSettle();
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
    expect(find.bySemanticsLabel('Profile options'), findsNothing);
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

  testWidgets('signed in: Block asks, blocks and leaves the profile', (
    tester,
  ) async {
    final blocks = FakeBlocks();
    await pump(
      tester,
      blocks: blocks,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );
    await tester.tap(find.bySemanticsLabel('Profile options'));
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

  testWidgets('a guest can share but not report or block', (tester) async {
    await pump(
      tester,
      signedIn: false,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );
    await tester.tap(find.bySemanticsLabel('Profile options'));
    await tester.pumpAndSettle();
    expect(find.text('Share profile'), findsOneWidget);
    expect(find.text('Report @beasantos'), findsNothing);
    expect(find.text('Block @beasantos'), findsNothing);
  });

  testWidgets('signed in: Report profile asks why, then sends it', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );
    await tester.tap(find.bySemanticsLabel('Profile options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report @beasantos'));
    await tester.pumpAndSettle();

    expect(find.text('Report @beasantos?'), findsOneWidget);
    for (final reason in ProfileReportReason.values) {
      expect(find.text(reason.label), findsOneWidget);
    }
    await tester.tap(find.text(ProfileReportReason.impersonation.label));
    await tester.pumpAndSettle();
    expect(repo.profileReports, isEmpty);
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(repo.profileReports, [
      ('bea-id', ProfileReportReason.impersonation, null),
    ]);
    expect(find.text(ReviewReportSheet.sentMessage), findsOneWidget);
    expect(analytics.propertiesOf('profile_reported'), {
      'reason': ProfileReportReason.impersonation.wire,
    });
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed profile report keeps the sheet open', (tester) async {
    final repo = await pump(
      tester,
      repository: FakePublicProfileRepository(profile: beaProfile()),
    );
    repo.writeFailure = Exception('offline');
    await tester.tap(find.bySemanticsLabel('Profile options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report @beasantos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ProfileReportReason.spam.label));
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();
    expect(find.text('Report @beasantos?'), findsOneWidget);
    expect(find.text(ReviewReportSheet.sentMessage), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('a visitor sees no Ranked stat when nothing is ranked', (
    tester,
  ) async {
    await pump(
      tester,
      repository: FakePublicProfileRepository(
        profile: const PublicProfile(
          userId: 'bea-id',
          username: 'beasantos',
          reviewCount: 4,
          rankedCount: 0,
          cupCount: 8,
        ),
      ),
    );
    expect(find.text('Ranked'), findsNothing);
    expect(find.bySemanticsLabel('0 Cups'), findsOneWidget);
    expect(find.text('No cups yet'), findsOneWidget);
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
