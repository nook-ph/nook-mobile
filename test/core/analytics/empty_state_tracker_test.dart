import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/empty_state_tracker.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';

import 'recording_analytics.dart';

Widget _tracker(String reason) => Directionality(
  textDirection: TextDirection.ltr,
  child: EmptyStateTracker(
    screen: 'map',
    reason: reason,
    child: const Text('empty'),
  ),
);

void main() {
  testWidgets('logs once on show, again only when the reason changes', (
    tester,
  ) async {
    final analytics = RecordingAnalytics.install(addTearDown);

    await tester.pumpWidget(_tracker('filtered'));
    await tester.pumpWidget(_tracker('filtered'));
    expect(find.text('empty'), findsOneWidget);
    expect(analytics.flat, [
      [
        EmptyStateEvents.shown,
        {'screen': 'map', 'reason': 'filtered'},
      ],
    ]);

    await tester.pumpWidget(_tracker('outside_cebu'));
    expect(analytics.names, [EmptyStateEvents.shown, EmptyStateEvents.shown]);
    expect(analytics.propertiesOf(EmptyStateEvents.shown), {
      'screen': 'map',
      'reason': 'outside_cebu',
    });
  });

  testWidgets('sticky: a remount with the same reason logs nothing until '
      'reset', (tester) async {
    final analytics = RecordingAnalytics.install(addTearDown);
    addTearDown(() => EmptyStateTracker.reset('map'));
    Widget sticky() => Directionality(
      textDirection: TextDirection.ltr,
      child: EmptyStateTracker(
        screen: 'map',
        reason: 'outside_cebu',
        sticky: true,
        child: const Text('empty'),
      ),
    );

    // Empty, skeleton, empty again: one pan.
    await tester.pumpWidget(sticky());
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(sticky());
    expect(analytics.names, [EmptyStateEvents.shown]);

    // Results came back in between: a new empty state.
    EmptyStateTracker.reset('map');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(sticky());
    expect(analytics.names, [EmptyStateEvents.shown, EmptyStateEvents.shown]);
  });
}
