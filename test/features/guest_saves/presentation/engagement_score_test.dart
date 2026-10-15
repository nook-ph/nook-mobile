import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/saves_events.dart';
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    analytics = RecordingAnalytics.install(addTearDown);
    clock = DateTime.utc(2026, 10, 16, 9);
    signedIn = false;
    sheets = 0;
    answer = const SignUpAskAnswer(accepted: false);
    score = EngagementScore(
      store: EngagementStore(),
      now: () => clock,
      isSignedIn: () => signedIn,
      threshold: SignUpAskRules.threshold,
    );
  });

  Future<void> earn(int fives) async {
    for (var i = 0; i < fives; i++) {
      await score.record(EngagementAction.save);
    }
  }

  Future<SignUpAskAnswer> fakeSheet(BuildContext _) async {
    sheets++;
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

  Future<bool> ask(BuildContext context, {bool hasSaves = true}) =>
      score.maybeAsk(
        context,
        trigger: SignUpAskTrigger.afterSave,
        hasSaves: hasSaves,
        showSheet: fakeSheet,
      );

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
      expect(await ask(context, hasSaves: false), isFalse);
      expect(sheets, 0);
    });
  });

  testWidgets('dismissing takes 5 off and waits a week', (tester) async {
    final context = await host(tester);
    await tester.runAsync(() async {
      await earn(5);
      expect(await ask(context), isTrue);
      expect(analytics.propertiesOf(SavesEvents.signUpAskDismissed), {
        'trigger': SignUpAskTrigger.afterSave,
        'score': 25.0,
        'ask_number': 1,
        'score_after': 20.0,
      });
      expect((await score.read()).score, 20);

      // Still at 20, but within the week.
      clock = clock.add(const Duration(days: 6));
      expect(await ask(context), isFalse);

      clock = clock.add(const Duration(days: 1));
      expect(await ask(context), isTrue);
      expect(sheets, 2);
    });
  });

  testWidgets('three asks at most', (tester) async {
    final context = await host(tester);
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await earn(5);
        await ask(context);
        clock = clock.add(const Duration(days: 8));
      }
      expect(sheets, 3);
      expect((await score.read()).asks, 3);
    });
  });

  testWidgets('accepting logs the provider and keeps the score', (
    tester,
  ) async {
    final context = await host(tester);
    await tester.runAsync(() async {
      answer = const SignUpAskAnswer(accepted: true, provider: 'google');
      await earn(4);
      await ask(context);
      expect(analytics.propertiesOf(SavesEvents.signUpAskAccepted), {
        'trigger': SignUpAskTrigger.afterSave,
        'score': 20.0,
        'ask_number': 1,
        'provider': 'google',
      });
      expect(analytics.names, isNot(contains(SavesEvents.signUpAskDismissed)));
      expect((await score.read()).score, 20);
    });
  });

  test('a return session within 30 days adds 5', () async {
    await score.recordSession();
    clock = clock.add(const Duration(days: 2));
    await score.recordSession();
    expect((await score.read()).score, 5);
  });
}
