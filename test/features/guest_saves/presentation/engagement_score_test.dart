import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:nook/core/analytics/saves_events.dart';
import 'package:nook/core/presentation/session_ask_budget.dart';
import 'package:nook/core/presentation/widgets/guest_sign_in_sheet.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/features/guest_saves/data/engagement_store.dart';
import 'package:nook/features/guest_saves/domain/sign_up_ask_rules.dart';
import 'package:nook/features/guest_saves/presentation/engagement_score.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/analytics/recording_analytics.dart';

void main() {
  late RecordingAnalytics analytics;
  late DateTime clock;
  late bool signedIn;
  late EngagementScore score;
  late int sheets;
  late SignUpAskAnswer answer;
  late SignUpAskCopy? lastCopy;
  late StreamController<void> sessions;
  late SessionAskBudget budget;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    analytics = RecordingAnalytics.install(addTearDown);
    clock = DateTime.utc(2026, 10, 16, 9);
    signedIn = false;
    sheets = 0;
    lastCopy = null;
    answer = const SignUpAskAnswer(dismissal: GuestSheetDismissal.notNow);
    sessions = StreamController<void>.broadcast();
    addTearDown(sessions.close);
    budget = SessionAskBudget.instance..resetForTest();
    addTearDown(budget.resetForTest);
    score = EngagementScore(
      store: EngagementStore(),
      now: () => clock,
      isSignedIn: () => signedIn,
      sessionStarts: () => sessions.stream,
      threshold: SignUpAskRules.threshold,
    );
  });

  Future<void> earn(int fives) async {
    for (var i = 0; i < fives; i++) {
      await score.record(EngagementAction.save);
    }
  }

  Future<SignUpAskAnswer> fakeSheet(BuildContext _, SignUpAskCopy copy) async {
    sheets++;
    lastCopy = copy;
    return answer;
  }

  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );
    return context;
  }

  Future<bool> ask(
    BuildContext context, {
    int savesCount = 1,
    SignUpAskSave? saved,
  }) async => (await score.maybeAsk(
    context,
    trigger: SignUpAskTrigger.afterSave,
    savesCount: savesCount,
    saved: saved,
    showSheet: fakeSheet,
  )).shown;

  /// A new session: the budget is whole again (as GuestSavesSync does).
  void newSession() => budget.newSession();

  test('an account earns nothing', () async {
    signedIn = true;
    await earn(5);
    expect((await score.read()).score, 0);
  });

  test('points add up and persist across instances', () async {
    await earn(2);
    await score.record(EngagementAction.cafeView);
    final again = EngagementScore(
      store: EngagementStore(),
      isSignedIn: () => false,
    );
    expect((await again.read()).score, 10.5);
  });

  testWidgets('under 20 nothing is shown', (tester) async {
    final context = await host(tester);
    await tester.runAsync(() async {
      await earn(3);
      expect(await ask(context), isFalse);
      expect(sheets, 0);
      expect(analytics.names, isNot(contains(SavesEvents.signUpAskShown)));
    });
  });

  testWidgets('at 20 the sheet shows once, logged with score and trigger', (
    tester,
  ) async {
    final context = await host(tester);
    await tester.runAsync(() async {
      await earn(4);
      expect(await ask(context), isTrue);
      expect(sheets, 1);
      expect(analytics.propertiesOf(SavesEvents.signUpAskShown), {
        'trigger': SignUpAskTrigger.afterSave,
        'score': 20.0,
        'ask_number': 1,
      });
    });
  });

  testWidgets('a guest with no saves is never asked', (tester) async {
    final context = await host(tester);
    await tester.runAsync(() async {
      await earn(6);
      expect(await ask(context, savesCount: 0), isFalse);
      expect(sheets, 0);
    });
  });

  testWidgets('dismissing takes 5 off, raises the bar and waits a week', (
    tester,
  ) async {
    final context = await host(tester);
    await tester.runAsync(() async {
      await earn(5);
      expect(await ask(context, savesCount: 4), isTrue);
      expect(analytics.propertiesOf(SavesEvents.signUpAskDismissed), {
        'trigger': SignUpAskTrigger.afterSave,
        'score': 25.0,
        'ask_number': 1,
        'score_after': 20.0,
        'how': 'not_now',
        'saves_count': 4,
      });
      final after = await score.read();
      expect(after.score, 20);
      expect(after.declines, 1);
      expect(score.declines.value, 1);

      // 30 is the bar now; a week has to pass too.
      await earn(2);
      newSession();
      clock = clock.add(const Duration(days: 6));
      expect(await ask(context), isFalse);

      clock = clock.add(const Duration(days: 1));
      expect(await ask(context), isTrue);
      expect(sheets, 2);
    });
  });

  testWidgets('three asks at most, the third once saves have doubled', (
    tester,
  ) async {
    final context = await host(tester);
    await tester.runAsync(() async {
      for (var i = 0; i < 5; i++) {
        await earn(10);
        newSession();
        await ask(context, savesCount: 3 + i);
        clock = clock.add(const Duration(days: 22));
      }
      // Asks 1 and 2 at 3 and 4 saves; the third waited for 8.
      expect(sheets, 2);
      newSession();
      await ask(context, savesCount: 8);
      expect(sheets, 3);
      clock = clock.add(const Duration(days: 60));
      newSession();
      await earn(20);
      await ask(context, savesCount: 50);
      expect(sheets, 3);
      expect((await score.read()).asks, 3);
    });
  });

  testWidgets('ask 1 confirms the save and names the count; ask 2 states '
      'the stake and offers to stay on this phone', (tester) async {
    final context = await host(tester);
    await tester.runAsync(() async {
      await earn(4);
      const saved = SignUpAskSave(
        cafeName: 'Flavour Coffee',
        status: CafeStatus.wantToTry,
      );
      await ask(context, savesCount: 4, saved: saved);
      expect(lastCopy?.confirmation, 'Flavour Coffee saved');
      expect(lastCopy?.title, 'Keep your 4 cafes on any phone');
      expect(lastCopy?.stayLabel, isNull);

      await earn(4);
      newSession();
      clock = clock.add(const Duration(days: 8));
      answer = const SignUpAskAnswer(
        dismissal: GuestSheetDismissal.stayOnPhone,
      );
      await ask(context, savesCount: 9);
      expect(lastCopy?.confirmation, isNull);
      expect(lastCopy?.title, 'Your 9 cafes are only on this phone');
      expect(lastCopy?.stayLabel, SignUpAskCopy.stayOnPhoneLabel);
      expect(
        analytics.propertiesOf(SavesEvents.signUpAskDismissed)?['how'],
        'stay_on_phone',
      );

      // Staying ends score asks, however much the guest does.
      await earn(20);
      newSession();
      clock = clock.add(const Duration(days: 90));
      expect(await ask(context, savesCount: 40), isFalse);
      expect(sheets, 2);
    });
  });

  group('session budget', () {
    testWidgets('one sheet a session: a second value moment is held back', (
      tester,
    ) async {
      final context = await host(tester);
      await tester.runAsync(() async {
        await earn(10);
        expect(await ask(context), isTrue);
        // Back over the bar and past the week, same session.
        clock = clock.add(const Duration(days: 8));
        await earn(10);
        expect(await ask(context), isFalse);
        expect(analytics.propertiesOf(SavesEvents.signUpAskSuppressed), {
          'reason': 'session_budget',
          'trigger': SignUpAskTrigger.afterSave,
        });
        newSession();
        expect(await ask(context), isTrue);
      });
    });

    testWidgets('the notification pre-prompt spends it for the score ask', (
      tester,
    ) async {
      final context = await host(tester);
      await tester.runAsync(() async {
        await earn(4);
        budget.spend(SessionAskKind.notificationPrePrompt);
        expect(await ask(context), isFalse);
        expect(sheets, 0);
      });
    });

    testWidgets('the score ask spends it for the pre-prompt', (tester) async {
      final context = await host(tester);
      await tester.runAsync(() async {
        await earn(4);
        expect(budget.canShowSheet, isTrue);
        await ask(context);
        expect(budget.canShowSheet, isFalse);
      });
    });

    testWidgets('a sign-in sheet the person opened blocks score asks, '
        'but not the pre-prompt', (tester) async {
      final context = await host(tester);
      await tester.runAsync(() async {
        await earn(4);
        budget.blockScoreAsks(SessionAskKind.pullSignIn);
        expect(await ask(context), isFalse);
        expect(budget.canShowSheet, isTrue);
        newSession();
        expect(await ask(context), isTrue);
      });
    });

    testWidgets('suppressions are logged once per reason a session', (
      tester,
    ) async {
      final context = await host(tester);
      await tester.runAsync(() async {
        await earn(1);
        await ask(context);
        await ask(context);
        expect(
          analytics.names
              .where((n) => n == SavesEvents.signUpAskSuppressed)
              .length,
          1,
        );
        expect(
          analytics.propertiesOf(SavesEvents.signUpAskSuppressed)?['reason'],
          'below_threshold',
        );
      });
    });
  });

  group('signup_ask_completed', () {
    testWidgets('Google that signs in completes at once', (tester) async {
      final context = await host(tester);
      await tester.runAsync(() async {
        await earn(4);
        await score.maybeAsk(
          context,
          trigger: SignUpAskTrigger.afterSave,
          savesCount: 1,
          showSheet: (_, _) async {
            signedIn = true;
            return const SignUpAskAnswer(provider: 'google');
          },
        );
        expect(analytics.names, contains(SavesEvents.signUpAskAccepted));
        expect(
          analytics.propertiesOf(SavesEvents.signUpAskCompleted)?['provider'],
          'google',
        );
        expect(
          analytics.names,
          isNot(contains(SavesEvents.signUpAskDismissed)),
        );
      });
    });

    testWidgets('email is not completed until a session starts, and backs '
        'off like a decline meanwhile', (tester) async {
      final context = await host(tester);
      await tester.runAsync(() async {
        answer = const SignUpAskAnswer(provider: 'email');
        await earn(4);
        final result = await score.maybeAsk(
          context,
          trigger: SignUpAskTrigger.afterSave,
          savesCount: 1,
          showSheet: fakeSheet,
        );
        // /login is on top now: the caller shows no save toast over it.
        expect(result, SignUpAskResult.signInStarted);
        expect(analytics.names, contains(SavesEvents.signUpAskAccepted));
        expect(
          analytics.names,
          isNot(contains(SavesEvents.signUpAskCompleted)),
        );
        expect(
          analytics.names,
          isNot(contains(SavesEvents.signUpAskDismissed)),
        );
        expect((await score.read()).declines, 1);

        sessions.add(null);
        await Future<void>.delayed(Duration.zero);
        expect(
          analytics.propertiesOf(SavesEvents.signUpAskCompleted)?['provider'],
          'email',
        );
      });
    });
  });

  testWidgets('a sign-in that finishes keeps the score', (tester) async {
    final context = await host(tester);
    await tester.runAsync(() async {
      await earn(4);
      await score.maybeAsk(
        context,
        trigger: SignUpAskTrigger.afterSave,
        savesCount: 1,
        showSheet: (_, _) async {
          signedIn = true;
          return const SignUpAskAnswer(provider: 'google');
        },
      );
      expect(analytics.propertiesOf(SavesEvents.signUpAskAccepted), {
        'trigger': SignUpAskTrigger.afterSave,
        'score': 20.0,
        'ask_number': 1,
        'provider': 'google',
      });
      signedIn = false;
      expect((await score.read()).score, 20);
    });
  });

  test('a save earns its points once per cafe; Undo takes them back', () async {
    await score.recordSave('a');
    await score.recordSave('a');
    expect((await score.read()).score, 5);
    await score.recordUnsave('a');
    await score.recordSave('a');
    await score.recordUnsave('a');
    expect((await score.read()).score, 0);
  });

  test('a return session within 30 days adds 5', () async {
    await score.recordSession();
    clock = clock.add(const Duration(days: 2));
    await score.recordSession();
    expect((await score.read()).score, 5);
  });
}
