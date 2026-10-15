import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/features/guest_saves/data/guest_saves_store.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/guest_saves/presentation/pages/guest_saved_page.dart';
import 'package:nook/features/guest_saves/presentation/save_actions.dart';
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
}
