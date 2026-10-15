import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/analytics/screen_tracking.dart';
import 'package:nook/features/home_page/presentation/widgets/home_card_section.dart';
import 'package:nook/features/home_page/presentation/widgets/home_rail_impression.dart';

import '../../../../core/analytics/recording_analytics.dart';

/// A tall feed: rail `a` at the top, rail `b` far below the fold.
Widget _feed() => MaterialApp(
  home: Scaffold(
    body: ListView(
      children: [
        const HomeRailImpression(rail: 'a', child: SizedBox(height: 200)),
        const SizedBox(height: 2000),
        const HomeRailImpression(rail: 'b', child: SizedBox(height: 200)),
      ],
    ),
  ),
);

List<Object?> _rails(RecordingAnalytics a) => [
  for (final e in a.events)
    if (e.$1 == HomeRailEvents.impression) e.$2?['rail'],
];

void main() {
  late RecordingAnalytics analytics;

  setUp(() {
    analytics = RecordingAnalytics.install(addTearDown);
    HomeRailImpression.resetForTest();
    ScreenTracker.instance.resetForTest();
  });

  testWidgets('logs a rail when it scrolls into view, once per visit', (
    tester,
  ) async {
    await tester.pumpWidget(_feed());
    await tester.pump();
    expect(_rails(analytics), ['a']);

    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(_rails(analytics), ['a', 'b']);

    // Back up and down again: same visit, nothing new.
    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(_rails(analytics), ['a', 'b']);
  });

  testWidgets('a new Home visit logs again; another screen does not', (
    tester,
  ) async {
    await tester.pumpWidget(_feed());
    await tester.pump();
    expect(_rails(analytics), ['a']);

    ScreenTracker.instance.report('Cafe');
    await tester.pump();
    expect(_rails(analytics), ['a']);

    ScreenTracker.instance.report(ScreenNames.home);
    await tester.pump();
    expect(_rails(analytics), ['a', 'a']);
  });

  test('a rail id falls back to the title in snake_case', () {
    expect(
      HomeCafeSection.railIdFor('Specialty coffee near you'),
      'specialty_coffee_near_you',
    );
    expect(HomeCafeSection.railIdFor('Laptop-friendly'), 'laptop_friendly');
  });
}
