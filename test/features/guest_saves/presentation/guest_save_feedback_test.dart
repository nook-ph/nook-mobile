import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/guest_saves/data/engagement_store.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/engagement_score.dart';
import 'package:nook/features/guest_saves/presentation/save_actions.dart';
import 'package:nook/injection_container.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/analytics/recording_analytics.dart';

const _a = CafeSnapshot(id: 'a', name: 'Kape Uno');
const _b = CafeSnapshot(id: 'b', name: 'Brew Szn');

void main() {
  late GuestSavesCubit saves;
  late BuildContext context;
  late RecordingAnalytics analytics;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    analytics = RecordingAnalytics.install(addTearDown);
    saves = GuestSavesCubit(store: GuestSavesStore());
  });

  tearDown(() async {
    await saves.close();
    if (sl.isRegistered<EngagementScore>()) {
      await sl.unregister<EngagementScore>();
    }
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    BlocProvider.value(
      value: saves,
      child: MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    ),
  );

  /// The write is real (SharedPreferences), then the toast fades in.
  Future<void> save(
    WidgetTester tester,
    CafeSnapshot cafe, {
    String? source,
  }) async {
    // Not awaited: with the ask showing, it ends only when the sheet does.
    await tester.runAsync(() async {
      unawaited(
        toggleGuestStatus(
          context,
          cafe: cafe,
          tapped: CafeStatus.wantToTry,
          source: source,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
  }

  testWidgets('the first save says where it went, with Undo and View; later '
      'saves name the list with Undo and View', (tester) async {
    await pump(tester);

    await save(tester, _a);
    expect(find.text(firstSaveMessage), findsOneWidget);
    expect(find.text(saveUndoLabel), findsOneWidget);
    expect(find.text(saveViewLabel), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
    await settle(tester);

    await save(tester, _b);
    expect(find.text(firstSaveMessage), findsNothing);
    expect(find.text('Saved to Want to try'), findsOneWidget);
    expect(find.text(saveUndoLabel), findsOneWidget);
    expect(find.text(saveViewLabel), findsOneWidget);

    await tester.tap(find.text(saveUndoLabel));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(saves.state.statusFor('b'), CafeStatus.none);
    expect(saves.state.statusFor('a'), CafeStatus.wantToTry);
    await settle(tester);
  });

  testWidgets('at the score the ask confirms the save first, and Not now '
      'still brings the save toast', (tester) async {
    // Made in the real zone: its write queue starts there.
    await tester.runAsync(() async {
      sl.registerSingleton<EngagementScore>(
        EngagementScore(
          store: EngagementStore(),
          isSignedIn: () => false,
          threshold: 5,
        ),
      );
    });
    await pump(tester);

    await save(tester, _a);
    await tester.pumpAndSettle();

    expect(find.text('Kape Uno saved'), findsOneWidget);
    expect(find.text('Keep your cafe on any phone'), findsOneWidget);
    expect(find.text(firstSaveMessage), findsNothing);
    expect(
      analytics.propertiesOf(SavesEvents.signUpAskShown)?['trigger'],
      'after_save',
    );
    expect(saves.state.statusFor('a'), CafeStatus.wantToTry);

    await tester.tap(find.text('Not now'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keep your cafe on any phone'), findsNothing);
    expect(analytics.names, contains(SavesEvents.signUpAskDismissed));
    // The save is still confirmed, with Undo and View (N4).
    expect(find.text('Saved to Want to try'), findsOneWidget);
    expect(find.text(saveUndoLabel), findsOneWidget);
    expect(find.text(saveViewLabel), findsOneWidget);
    // Shown from the real zone, its close timer never runs in fake time.
    dismissToasts();
    await tester.pumpAndSettle();
  });

  testWidgets('Undo takes the save and its points back', (tester) async {
    late EngagementScore score;
    await tester.runAsync(() async {
      score = EngagementScore(
        store: EngagementStore(),
        isSignedIn: () => false,
        threshold: 99,
      );
      sl.registerSingleton<EngagementScore>(score);
    });
    await pump(tester);

    await save(tester, _a);
    await tester.tap(find.text(saveUndoLabel));
    // Undo runs in the test's zone: let its storage writes finish.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(saves.state.statusFor('a'), CafeStatus.none);
    expect(
      analytics.propertiesOf(SavesEvents.guestSaveRemoved)?['source'],
      'undo',
    );
    await tester.runAsync(() async {
      expect((await score.read()).score, 0);
    });
    await settle(tester);
  });

  testWidgets('with a screen reader on the removal toast waits to be closed', (
    tester,
  ) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: saves,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(accessibleNavigation: true),
            child: Builder(
              builder: (c) {
                context = c;
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      ),
    );
    await save(tester, _a);
    await save(tester, _a);
    expect(find.text('Removed from Want to try'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Removed from Want to try'), findsOneWidget);
    // Close is a real control for TalkBack: its node carries the tap (N1).
    final semantics = tester.ensureSemantics();
    final close = find.semantics.byLabel('Close');
    expect(close, findsOne);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Close')),
      matchesSemantics(label: 'Close', isButton: true, hasTapAction: true),
    );
    tester.semantics.tap(close);
    semantics.dispose();
    // Shown from the real zone, so it fades out in real time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Removed from Want to try'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the top save on a Been cafe offers the move, never switches', (
    tester,
  ) async {
    await pump(tester);
    await tester.runAsync(() => saves.set(_a, CafeStatus.been));

    await tester.runAsync(() async {
      unawaited(guestTopSave(context, cafe: _a));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(alreadyBeenMessage), findsOneWidget);
    expect(saves.state.statusFor('a'), CafeStatus.been);

    await tester.tap(find.text(moveToWantToTryLabel));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(saves.state.statusFor('a'), CafeStatus.wantToTry);
    await settle(tester);
  });

  testWidgets('a save from the directions nudge never asks (one ask a trip)', (
    tester,
  ) async {
    // Made in the real zone: its write queue starts there.
    await tester.runAsync(() async {
      sl.registerSingleton<EngagementScore>(
        EngagementScore(
          store: EngagementStore(),
          isSignedIn: () => false,
          threshold: 5,
        ),
      );
    });
    await pump(tester);

    await save(tester, _a, source: SavesSource.directionsNudge);
    await tester.pumpAndSettle();
    expect(find.text(keepSavesSheetTitle), findsNothing);
    expect(find.text(firstSaveMessage), findsOneWidget);
    expect(analytics.names, isNot(contains(SavesEvents.signUpAskShown)));
    await settle(tester);
  });
}
