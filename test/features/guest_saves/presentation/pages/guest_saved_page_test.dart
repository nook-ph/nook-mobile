import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/features/guest_saves/data/engagement_store.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/sign_up_ask_rules.dart';
import 'package:nook/features/guest_saves/presentation/engagement_score.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/pages/guest_saved_page.dart';
import 'package:nook/features/guest_saves/presentation/save_actions.dart';
import 'package:nook/features/guest_saves/presentation/widgets/sign_up_ask_on_saved.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/analytics/recording_analytics.dart';

void main() {
  late RecordingAnalytics analytics;
  late GuestSavesCubit saves;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    analytics = RecordingAnalytics.install(addTearDown);
    saves = GuestSavesCubit(store: GuestSavesStore());
  });

  tearDown(() => saves.close());

  Future<void> pump(WidgetTester tester, {VoidCallback? onBrowse}) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: saves,
        child: MaterialApp(home: GuestSavedPage(onBrowse: onBrowse)),
      ),
    );
    await tester.runAsync(saves.load);
    await tester.pump();
  }

  testWidgets('with nothing saved, invites the first save', (tester) async {
    var browsed = false;
    await pump(tester, onBrowse: () => browsed = true);

    expect(find.text(GuestSavedPage.emptyTitle), findsOneWidget);
    expect(find.text(GuestSavedPage.keepTitle), findsNothing);
    expect(analytics.names, isNot(contains(SavesEvents.keepSavesPromptShown)));

    await tester.tap(find.text('Find a cafe'));
    expect(browsed, isTrue);
  });

  testWidgets('lists Want to Try and Been with the keep-saves card', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await saves.set(
        const CafeSnapshot(id: 'a', name: 'Kape Uno'),
        CafeStatus.wantToTry,
      );
      await saves.set(
        const CafeSnapshot(id: 'b', name: 'Brew Dos'),
        CafeStatus.been,
      );
    });
    analytics.events.clear();
    await pump(tester);
    await tester.pump();

    expect(find.text(GuestSavedPage.emptyTitle), findsNothing);
    expect(find.text(GuestSavedPage.keepTitle), findsOneWidget);
    expect(find.text('Want to try'), findsOneWidget);
    expect(find.text('Been'), findsOneWidget);
    expect(find.text('Kape Uno'), findsOneWidget);
    expect(find.text('Brew Dos'), findsOneWidget);
    // Shown once, however often the list rebuilds.
    expect(
      analytics.names.where((n) => n == SavesEvents.keepSavesPromptShown),
      hasLength(1),
    );
    expect(analytics.propertiesOf(SavesEvents.keepSavesPromptShown), {
      'surface': KeepSavesSurface.savedTab,
    });
  });

  testWidgets('Sign in opens the sign-in sheet with the keep-saves reason', (
    tester,
  ) async {
    await tester.runAsync(
      () => saves.set(
        const CafeSnapshot(id: 'a', name: 'Kape Uno'),
        CafeStatus.wantToTry,
      ),
    );
    await pump(tester);
    await tester.pump();
    analytics.events.clear();

    await tester.tap(find.text(GuestSavedPage.keepAction));
    await tester.pumpAndSettle();

    expect(find.text(keepSavesSheetReason), findsOneWidget);
    expect(analytics.flat, [
      [
        SavesEvents.keepSavesPromptTapped,
        {'surface': KeepSavesSurface.savedTab},
      ],
      [
        SignInPromptEvents.shown,
        {'trigger': 'keep_saves_saved_tab'},
      ],
    ]);
  });

  testWidgets('a tap on the card body signs in too (one button)', (
    tester,
  ) async {
    await tester.runAsync(
      () => saves.set(
        const CafeSnapshot(id: 'a', name: 'Kape Uno'),
        CafeStatus.wantToTry,
      ),
    );
    await pump(tester);
    await tester.pump();

    await tester.tap(find.text(GuestSavedPage.keepBody));
    await tester.pumpAndSettle();
    expect(find.text(keepSavesSheetReason), findsOneWidget);
  });

  testWidgets('the Saved ask is not made again by scrolling the list', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        await saves.set(
          CafeSnapshot(id: 'c$i', name: 'Cafe $i'),
          CafeStatus.wantToTry,
        );
      }
    });
    await pump(tester);
    await tester.pump();
    final before = tester.state(find.byType(SignUpAskOnSaved));

    await tester.drag(find.byType(ListView), const Offset(0, -6000));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, 6000));
    await tester.pump();

    expect(tester.state(find.byType(SignUpAskOnSaved)), same(before));
  });

  group('after two declined asks', () {
    tearDown(() async {
      if (sl.isRegistered<EngagementScore>()) {
        await sl.unregister<EngagementScore>();
      }
    });

    testWidgets('the card becomes one row below the lists', (tester) async {
      await tester.runAsync(() async {
        await EngagementStore().write(
          const EngagementState(asks: 2, declines: 2),
        );
        sl.registerSingleton<EngagementScore>(
          EngagementScore(
            store: EngagementStore(),
            isSignedIn: () => false,
            threshold: 99,
          ),
        );
        await saves.set(
          const CafeSnapshot(id: 'a', name: 'Kape Uno'),
          CafeStatus.wantToTry,
        );
      });
      await pump(tester);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(find.text(GuestSavedPage.keepTitle), findsNothing);
      expect(find.text(GuestSavedPage.keepRowLabel), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(GuestSavedPage.keepRowLabel)).dy,
        greaterThan(tester.getTopLeft(find.text('Kape Uno')).dy),
      );
      // Logged once the declines were read, so with the row's surface.
      expect(analytics.propertiesOf(SavesEvents.keepSavesPromptShown), {
        'surface': KeepSavesSurface.savedRow,
      });

      analytics.events.clear();
      await tester.tap(find.text(GuestSavedPage.keepRowLabel));
      await tester.pumpAndSettle();
      expect(find.text(keepSavesSheetReason), findsOneWidget);
      expect(analytics.propertiesOf(SavesEvents.keepSavesPromptTapped), {
        'surface': KeepSavesSurface.savedRow,
      });
    });
  });
}
