import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/profile/presentation/pages/profile_pagev2.dart';
import 'package:nook/features/profile/presentation/pages/settings_page.dart';
import 'package:nook/features/profile/presentation/widgets/profile_header.dart';
import 'package:nook/features/public_profile/presentation/cubit/profile_visibility_cubit.dart';

import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';

import '../lists/lists_fixtures.dart'
    show FakeRankingRepository, ranking, rankingCubit;
import '../profile/profile_test_support.dart';
import 'public_profile_fakes.dart';

void main() {
  group('the owner’s own profile', () {
    late List<({String username, String name, bool own})> shared;
    late List<String> previewed;

    setUp(() {
      shared = [];
      previewed = [];
    });

    Future<void> pump(
      WidgetTester tester, {
      ProfileVisibilityCubit? visibility,
      int liked = 3,
    }) async {
      final rankings = FakeRankingRepository()
        ..serverRankings = [
          for (var i = 1; i <= liked; i++)
            ranking('c$i', RankBucket.liked, i, 10.0 - i),
        ];
      await tester.pumpWidget(
        profileHost(
          cubit: FakeProfileCubit(profile()),
          visibility: visibility,
          ranking: rankingCubit(rankings),
          page: ProfileView(
            shareProfile:
                ({required username, required name, own = false}) async =>
                    shared.add((username: username, name: name, own: own)),
            openPreview: previewed.add,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      // Gallery is the first tab; the hint and Preview live on Ranked.
      // "Ranked" is also a stat label, so tap the one in the tab row.
      await tester.tap(
        find.descendant(
          of: find.byType(ProfileTabs),
          matching: find.byTooltip('Ranked'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('keeps the private Ranked tab, says only they see it', (
      tester,
    ) async {
      await pump(tester);
      // The tab is a trophy with a lock; its word is for screen readers.
      expect(find.text('Ranked'), findsOneWidget); // the stat
      expect(find.bySemanticsLabel('Ranked, only you can see it'), findsOne);
      expect(find.byIcon(LucideIcons.lock), findsWidgets);
      expect(find.byTooltip('Lists'), findsOneWidget);
      expect(
        find.text(
          "Only you see your ranking. Visitors see how many cafes you've "
          'ranked.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Preview opens the visitor view of their own profile', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('Preview what visitors see'));
      expect(previewed, ['user-1']);
    });

    testWidgets('the hint follows the switch', (tester) async {
      final visibility = ProfileVisibilityCubit(
        repository: FakePublicProfileRepository(highlights: false),
      );
      await pump(tester, visibility: visibility);
      await tester.pump();
      expect(find.text('Only you see your ranking.'), findsOneWidget);
    });

    testWidgets('Share profile shares their own link', (tester) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('Share profile'));
      await tester.pumpAndSettle();
      // The sheet also says what the link shows and who can see it.
      expect(find.text('See what visitors see'), findsOneWidget);
      expect(find.text('Gallery privacy'), findsOneWidget);
      await tester.tap(find.text('Share profile').last);
      await tester.pumpAndSettle();
      expect(shared.single.username, 'saiimonn_');
      expect(shared.single.own, isTrue);
    });

    testWidgets('Preview is reachable from Share profile too', (tester) async {
      await pump(tester);
      await tester.tap(find.bySemanticsLabel('Share profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See what visitors see'));
      await tester.pumpAndSettle();
      expect(previewed, ['user-1']);
    });

    testWidgets('the Share sheet says when the gallery is hidden', (
      tester,
    ) async {
      final visibility = ProfileVisibilityCubit(
        repository: FakePublicProfileRepository(highlights: false),
      );
      await pump(tester, visibility: visibility);
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Share profile'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your gallery is hidden from visitors'),
        findsOneWidget,
      );
    });
  });

  group('Settings → Privacy', () {
    Future<FakePublicProfileRepository> pump(
      WidgetTester tester, {
      bool highlights = true,
    }) async {
      final repo = FakePublicProfileRepository(highlights: highlights);
      await tester.pumpWidget(
        profileHost(
          visibility: ProfileVisibilityCubit(repository: repo),
          page: SettingsPage(
            currentUser: () => userWith('email'),
            readLocationStatus: () async => SettingsLocationStatus.on,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return repo;
    }

    Switch toggle(WidgetTester tester) =>
        tester.widget<Switch>(find.byType(Switch));

    testWidgets('the switch is on by default and turns off', (tester) async {
      final repo = await pump(tester);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Show my gallery on my profile'), findsOneWidget);
      expect(toggle(tester).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(repo.writes, [false]);
      expect(toggle(tester).value, isFalse);
    });

    testWidgets('a failed save puts the switch back and says so', (
      tester,
    ) async {
      final repo = await pump(tester);
      repo.writeFailure = Exception('offline');
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(toggle(tester).value, isTrue);
      expect(
        find.text('Could not save that. Please try again.'),
        findsOneWidget,
      );
      await letToastExpire(tester);
    });
  });
}
