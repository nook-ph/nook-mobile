import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home_widget/domain/saved_cafes_widget_data.dart';

Map<String, dynamic> _every(String open, String close) => {
  for (final d in [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ])
    d: {'open': open, 'close': close},
};

/// Manila wall-clock time as an instant (UTC+8).
DateTime _manila(int day, int hour, [int minute = 0]) => DateTime.utc(
  2026,
  10,
  day,
  hour,
  minute,
).subtract(const Duration(hours: 8));

void main() {
  // 2026-10-14 is a Wednesday.
  final wed = _manila(14, 12);

  group('frameAt', () {
    test('open cafes first, nearest first, then by soonest opening', () {
      final cafes = [
        WidgetCafe(
          id: 'late',
          name: 'Late',
          operatingHours: _every('18:00', '23:00'),
        ),
        WidgetCafe(
          id: 'far',
          name: 'Far',
          operatingHours: _every('08:00', '21:00'),
          distanceMeters: 4200,
        ),
        WidgetCafe(
          id: 'near',
          name: 'Near',
          operatingHours: _every('07:00', '20:30'),
          distanceMeters: 650,
        ),
        WidgetCafe(
          id: 'soon',
          name: 'Soon',
          operatingHours: _every('13:00', '22:00'),
        ),
      ];
      final frame = SavedCafesWidgetData.frameAt(cafes, wed);
      expect(frame.openCount, 2);
      expect(frame.rows.map((r) => r.cafeId), ['near', 'far', 'soon']);
      expect(frame.rows[0].line, 'Open until 8:30 PM · 650\u00A0m');
      expect(frame.rows[1].line, 'Open until 9 PM · 4.2\u00A0km');
      expect(frame.rows[2].line, 'Opens 1 PM');
      expect(frame.rows[2].tone, WidgetRowTone.closed);
    });

    test('without distances, open cafes keep the newest-saved order', () {
      final cafes = [
        WidgetCafe(
          id: 'a',
          name: 'A',
          operatingHours: _every('08:00', '21:00'),
        ),
        WidgetCafe(
          id: 'b',
          name: 'B',
          operatingHours: _every('07:00', '22:00'),
        ),
      ];
      final frame = SavedCafesWidgetData.frameAt(cafes, wed);
      expect(frame.rows.map((r) => r.cafeId), ['a', 'b']);
    });

    test('none open: next openings, tomorrow and a named day', () {
      final cafes = [
        WidgetCafe(
          id: 'fri',
          name: 'Weekend',
          operatingHours: {
            'friday': {'open': '09:00', 'close': '17:00'},
          },
        ),
        WidgetCafe(
          id: 'tmrw',
          name: 'Morning',
          operatingHours: _every('06:00', '11:00'),
        ),
        const WidgetCafe(id: 'unknown', name: 'No hours'),
      ];
      final frame = SavedCafesWidgetData.frameAt(cafes, wed);
      expect(frame.openCount, 0);
      expect(frame.rows.map((r) => r.line), [
        'Opens 6 AM tomorrow',
        'Opens 9 AM Friday',
        'Hours not listed',
      ]);
      expect(frame.rows.last.tone, WidgetRowTone.unknown);
    });

    test('closing soon within 30 minutes', () {
      final cafes = [
        WidgetCafe(
          id: 'a',
          name: 'A',
          operatingHours: _every('08:00', '12:20'),
        ),
      ];
      final frame = SavedCafesWidgetData.frameAt(cafes, wed);
      expect(frame.rows.single.line, 'Closes soon · 12:20 PM');
      expect(frame.rows.single.tone, WidgetRowTone.closingSoon);
    });

    test('at most three rows', () {
      final cafes = [
        for (var i = 0; i < 6; i++)
          WidgetCafe(
            id: '$i',
            name: 'Cafe $i',
            operatingHours: _every('08:00', '21:00'),
          ),
      ];
      final frame = SavedCafesWidgetData.frameAt(cafes, wed);
      expect(frame.rows, hasLength(3));
      expect(frame.openCount, 6);
    });
  });

  group('build', () {
    test('empty list is empty', () {
      final data = SavedCafesWidgetData.build(const [], now: wed);
      expect(data.isEmpty, isTrue);
      expect(data.frames.single.rows, isEmpty);
    });

    test('frames turn over when a cafe opens, starts closing and closes', () {
      final data = SavedCafesWidgetData.build([
        WidgetCafe(
          id: 'a',
          name: 'A',
          operatingHours: _every('13:00', '18:00'),
        ),
      ], now: wed);
      final at = data.frames.map((f) => f.at).toList();
      expect(at.first, wed);
      expect(at, contains(_manila(14, 13)));
      expect(at, contains(_manila(14, 17, 30)));
      expect(at, contains(_manila(14, 18)));
      // Midnight: "Opens 1 PM tomorrow" becomes "Opens 1 PM".
      expect(at, contains(_manila(15, 0)));
      expect(data.frames.first.rows.single.line, 'Opens 1 PM');
      final atOne = data.frames.firstWhere((f) => f.at == _manila(14, 13));
      expect(atOne.rows.single.line, 'Open until 6 PM');
      expect(atOne.openCount, 1);
      expect(data.until, wed.add(const Duration(days: 7)));
      expect(data.updateTimes.last, data.until);
    });

    test('no duplicate consecutive frames and every frame is in order', () {
      final data = SavedCafesWidgetData.build([
        WidgetCafe(
          id: 'a',
          name: 'A',
          operatingHours: _every('08:00', '21:00'),
        ),
        WidgetCafe(
          id: 'b',
          name: 'B',
          operatingHours: _every('08:00', '21:00'),
        ),
      ], now: wed);
      for (var i = 1; i < data.frames.length; i++) {
        expect(data.frames[i].at.isAfter(data.frames[i - 1].at), isTrue);
        expect(data.frames[i].sameAs(data.frames[i - 1]), isFalse);
      }
    });

    test('names cover every row; duplicate ids are dropped', () {
      final data = SavedCafesWidgetData.build([
        WidgetCafe(
          id: 'a',
          name: 'A',
          operatingHours: _every('08:00', '21:00'),
        ),
        WidgetCafe(
          id: 'a',
          name: 'A again',
          operatingHours: _every('08:00', '21:00'),
        ),
      ], now: wed);
      expect(data.names, {'a': 'A'});
      final json = data.toJson();
      expect(json['v'], 1);
      expect((json['frames'] as List).first, containsPair('o', 1));
    });
    group('turnovers', () {
      final data = SavedCafesWidgetData.build([
        WidgetCafe(
          id: 'a',
          name: 'A',
          operatingHours: _every('13:00', '18:00'),
        ),
      ], now: wed);

      test('the next redraw is the next opening, closing-soon or closing', () {
        expect(data.nextUpdateAfter(wed), _manila(14, 13));
        expect(data.nextUpdateAfter(_manila(14, 12, 59)), _manila(14, 13));
        // Exactly at a turnover, the one after it.
        expect(data.nextUpdateAfter(_manila(14, 13)), _manila(14, 17, 30));
        expect(data.nextUpdateAfter(_manila(14, 17, 45)), _manila(14, 18));
        expect(data.nextUpdateAfter(_manila(14, 18, 5)), _manila(15, 0));
      });

      test('after the last frame it is the end of the week, then nothing', () {
        final lastFrame = data.frames.last.at;
        expect(data.nextUpdateAfter(lastFrame), data.until);
        expect(data.nextUpdateAfter(data.until), isNull);
      });

      test('every update time is in the future of the write and ordered', () {
        final times = data.updateTimes;
        for (var i = 0; i < times.length; i++) {
          expect(times[i].isAfter(wed), isTrue);
          if (i > 0) expect(times[i].isAfter(times[i - 1]), isTrue);
        }
      });
    });

    group('distances go stale', () {
      final cafes = [
        WidgetCafe(
          id: 'newest',
          name: 'Newest',
          operatingHours: _every('08:00', '22:00'),
          distanceMeters: 5200,
        ),
        WidgetCafe(
          id: 'near',
          name: 'Near',
          operatingHours: _every('08:00', '22:00'),
          distanceMeters: 400,
        ),
      ];
      final data = SavedCafesWidgetData.build(cafes, now: wed);
      WidgetFrame frameAt(DateTime t) =>
          data.frames.lastWhere((f) => !f.at.isAfter(t));

      test('within 3 hours of the write: km shown, nearest first', () {
        final frame = frameAt(wed.add(const Duration(hours: 2, minutes: 59)));
        expect(frame.rows.map((r) => r.cafeId), ['near', 'newest']);
        expect(frame.rows.first.line, 'Open until 10 PM · 400\u00A0m');
      });

      test('from 3 hours on: no km, newest saved first', () {
        final cutoff = wed.add(SavedCafesWidgetData.distanceFreshFor);
        expect(data.frames.map((f) => f.at), contains(cutoff));
        for (final t in [cutoff, _manila(15, 9), _manila(20, 12)]) {
          final frame = frameAt(t);
          expect(frame.rows.map((r) => r.cafeId), [
            'newest',
            'near',
          ], reason: '$t');
          for (final r in frame.rows) {
            expect(r.line, isNot(contains('m')), reason: r.line);
          }
        }
      });

      test('no distances at all adds no cutoff frame', () {
        final plain = SavedCafesWidgetData.build([
          WidgetCafe(
            id: 'a',
            name: 'A',
            operatingHours: _every('08:00', '22:00'),
          ),
        ], now: wed);
        expect(
          plain.frames.map((f) => f.at),
          isNot(contains(wed.add(SavedCafesWidgetData.distanceFreshFor))),
        );
      });
    });
  });
}
