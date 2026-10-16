import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home_widget/domain/saved_cafes_widget_data.dart';

/// The widget shows the last frame that has started. For that to be right
/// at every moment, the frame picked at any minute of the week must say
/// what [SavedCafesWidgetData.frameAt] says for that minute.
void main() {
  const days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  Map<String, dynamic> week(Map<String, dynamic> Function(String day) f) => {
    for (final d in days) d: f(d),
  };

  final cafes = [
    // Overnight every day.
    WidgetCafe(
      id: 'night',
      name: 'Night',
      operatingHours: week((_) => {'open': '18:00', 'close': '03:00'}),
      distanceMeters: 900,
    ),
    // Runs to midnight, carries on to 02:00 the next day on weekends.
    WidgetCafe(
      id: 'chain',
      name: 'Chain',
      operatingHours: week(
        (d) => d == 'saturday' || d == 'sunday'
            ? {'open': '00:00', 'close': '02:00'}
            : {'open': '14:00', 'close': '24:00'},
      ),
      distanceMeters: 400,
    ),
    // Rest days and an odd close.
    WidgetCafe(
      id: 'rest',
      name: 'Rest',
      operatingHours: week(
        (d) => d == 'monday' || d == 'tuesday'
            ? {'closed': true}
            : {'open': '07:30', 'close': '15:45'},
      ),
    ),
    // Round the clock.
    WidgetCafe(
      id: 'always',
      name: 'Always',
      operatingHours: week((_) => {'open': '00:00', 'close': '24:00'}),
      distanceMeters: 2500,
    ),
    // Unknown hours.
    const WidgetCafe(id: 'unknown', name: 'Unknown'),
    // Morning only.
    WidgetCafe(
      id: 'morning',
      name: 'Morning',
      operatingHours: week((_) => {'open': '06:00', 'close': '11:00'}),
    ),
  ];

  for (final start in [
    DateTime.utc(2026, 10, 14, 4, 0), // Wed 12:00 Manila
    DateTime.utc(2026, 10, 17, 15, 37), // Sat 23:37 Manila
    DateTime.utc(2026, 10, 18, 17, 59), // Mon 01:59 Manila
  ]) {
    test('every minute of the week from $start', () {
      final data = SavedCafesWidgetData.build(cafes, now: start);
      final distancesUntil = start.add(SavedCafesWidgetData.distanceFreshFor);
      for (
        var t = start;
        t.isBefore(data.until);
        t = t.add(const Duration(minutes: 1))
      ) {
        final shown = data.frames.lastWhere((f) => !f.at.isAfter(t));
        final expected = SavedCafesWidgetData.frameAt(
          cafes,
          t,
          withDistances: t.isBefore(distancesUntil),
        );
        expect(
          shown.sameAs(expected),
          isTrue,
          reason:
              'at $t: shown ${shown.rows} (${shown.openCount} open), '
              'expected ${expected.rows} (${expected.openCount} open)',
        );
        for (final r in shown.rows) {
          expect(data.names.containsKey(r.cafeId), isTrue);
        }
      }
    });
  }
}
