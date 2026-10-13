import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/rage_tap_detector.dart';
import 'package:nook/core/analytics/screen_tracking.dart';

import 'recording_analytics.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  group('RageTapCounter', () {
    test('three quick taps in one spot are a rage tap', () {
      final c = RageTapCounter();
      expect(c.add(const Offset(100, 100), ms(0)), isFalse);
      expect(c.add(const Offset(105, 102), ms(300)), isFalse);
      expect(c.add(const Offset(98, 101), ms(600)), isTrue);
    });

    test('one burst reports once, then counting starts over', () {
      final c = RageTapCounter();
      for (var i = 0; i < 3; i++) {
        c.add(const Offset(10, 10), ms(i * 100));
      }
      expect(c.add(const Offset(10, 10), ms(300)), isFalse);
      expect(c.add(const Offset(10, 10), ms(400)), isFalse);
      expect(c.add(const Offset(10, 10), ms(500)), isTrue);
    });

    test('a slow tap or one elsewhere breaks the run', () {
      final c = RageTapCounter();
      c.add(const Offset(0, 0), ms(0));
      c.add(const Offset(0, 0), ms(200));
      expect(c.add(const Offset(0, 0), ms(1400)), isFalse); // too slow
      c.add(const Offset(0, 0), ms(1500));
      expect(c.add(const Offset(80, 0), ms(1600)), isFalse); // too far
    });
  });

  testWidgets('rapid taps send \$rageclick stamped with the screen', (
    tester,
  ) async {
    final analytics = RecordingAnalytics.install(addTearDown);
    ScreenTracker.instance.resetForTest();
    ScreenTracker.instance.report(ScreenNames.map);

    await tester.pumpWidget(const RageTapDetector(child: SizedBox.expand()));
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(const Offset(40, 60));
      await tester.pump(ms(100));
    }

    expect(analytics.names, [r'$rageclick']);
    final props = analytics.propertiesOf(r'$rageclick')!;
    expect(props[r'$screen_name'], ScreenNames.map);
    expect(props[r'$touch_x'], 40);
    expect(props[r'$touch_y'], 60);
  });

  testWidgets('a scroll is not counted as a tap', (tester) async {
    final analytics = RecordingAnalytics.install(addTearDown);
    await tester.pumpWidget(const RageTapDetector(child: SizedBox.expand()));
    for (var i = 0; i < 3; i++) {
      await tester.dragFrom(const Offset(40, 300), const Offset(0, -120));
      await tester.pump(ms(100));
    }
    expect(analytics.names, isEmpty);
  });
}
