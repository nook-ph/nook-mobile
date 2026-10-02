import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/onboarding/presentation/pages/onboarding_page.dart';

void main() {
  Future<List<int>> pumpOnboarding(WidgetTester tester) async {
    final finishes = <int>[];
    await tester.pumpWidget(
      MaterialApp(home: OnboardingPage(onFinish: () => finishes.add(1))),
    );
    await tester.pump();
    return finishes;
  }

  testWidgets('slide 1 has Skip and Next, copy left-aligned (A1)', (
    tester,
  ) async {
    final finishes = await pumpOnboarding(tester);
    expect(find.text('Find your\nperfect brew'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    expect(finishes, [1]);
  });

  testWidgets('the last slide drops Skip and reads Continue (A3)', (
    tester,
  ) async {
    final finishes = await pumpOnboarding(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Explore local\ncafes'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Join the coffee\ncommunity'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    expect(finishes, [1]);
  });

  testWidgets('fits a short phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpOnboarding(tester);
    expect(tester.takeException(), isNull);
  });
}
