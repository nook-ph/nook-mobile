import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/cafe_open_status.dart';

/// Manila is a fixed UTC+8, so a UTC instant plus 8 hours is the wall-clock
/// time the cafe's hours are written in. Tests pass UTC instants and name the
/// Manila time they correspond to.
DateTime manila(int year, int month, int day, int hour, [int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute).subtract(
      const Duration(hours: 8),
    );

Map<String, dynamic> day(String open, String close) => {
  'open': open,
  'close': close,
  'closed': false,
};

const Map<String, dynamic> closedDay = {
  'open': '',
  'close': '',
  'closed': true,
};

Map<String, dynamic> everyDay(Map<String, dynamic> hours) => {
  for (final key in const [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ])
    key: hours,
};

void main() {
  // 2026-07-21 is a Tuesday, 2026-07-22 a Wednesday.

  group('ordinary hours', () {
    // Volte Specialty Cafe: 8:00-22:00 every day, note the unpadded hour.
    final volte = everyDay(day('8:00', '22:00'));

    test('is open in the middle of the day', () {
      final status = CafeOpenStatus.resolve(
        volte,
        now: manila(2026, 7, 21, 14),
      );
      expect(status.state, CafeOpenState.open);
      expect(status.minutesUntilClose, 8 * 60);
    });

    test('is closed before opening', () {
      expect(
        CafeOpenStatus.resolve(volte, now: manila(2026, 7, 21, 7)).state,
        CafeOpenState.closed,
      );
    });

    test('is closed exactly at the closing minute', () {
      expect(
        CafeOpenStatus.resolve(volte, now: manila(2026, 7, 21, 22)).state,
        CafeOpenState.closed,
      );
    });

    test('is open exactly at the opening minute', () {
      expect(
        CafeOpenStatus.resolve(volte, now: manila(2026, 7, 21, 8)).state,
        CafeOpenState.open,
      );
    });

    test('warns when close is within the threshold', () {
      final status = CafeOpenStatus.resolve(
        volte,
        now: manila(2026, 7, 21, 21, 30),
      );
      expect(status.state, CafeOpenState.closingSoon);
      expect(status.minutesUntilClose, 30);
    });

    test('does not warn just outside the threshold', () {
      expect(
        CafeOpenStatus.resolve(volte, now: manila(2026, 7, 21, 21, 10)).state,
        CafeOpenState.open,
      );
    });
  });

  group('spans past midnight', () {
    // Cafe Elim: 8:00-3:00 every day. These are exactly the late-night cafes a
    // naive `now < close` comparison would report closed all day.
    final elim = everyDay(day('8:00', '3:00'));

    test('is open late at night, before midnight', () {
      expect(
        CafeOpenStatus.resolve(elim, now: manila(2026, 7, 21, 23)).state,
        CafeOpenState.open,
      );
    });

    test('is open after midnight, on the previous day\'s span', () {
      final status = CafeOpenStatus.resolve(
        elim,
        now: manila(2026, 7, 22, 1),
      );
      expect(status.state, CafeOpenState.open);
      expect(status.minutesUntilClose, 2 * 60);
    });

    test('is closed in the gap between closing and reopening', () {
      expect(
        CafeOpenStatus.resolve(elim, now: manila(2026, 7, 22, 5)).state,
        CafeOpenState.closed,
      );
    });

    test('spills over even when today itself is a rest day', () {
      final hours = {
        ...everyDay(day('18:00', '2:00')),
        'wednesday': closedDay,
      };
      expect(
        CafeOpenStatus.resolve(hours, now: manila(2026, 7, 22, 1)).state,
        CafeOpenState.open,
      );
      expect(
        CafeOpenStatus.resolve(hours, now: manila(2026, 7, 22, 20)).state,
        CafeOpenState.closed,
      );
    });
  });

  group('rest days', () {
    test('a day flagged closed reports closed, not unknown', () {
      final hours = {...everyDay(day('11:00', '20:00')), 'tuesday': closedDay};
      expect(
        CafeOpenStatus.resolve(hours, now: manila(2026, 7, 21, 14)).state,
        CafeOpenState.closed,
      );
    });
  });

  group('unusable data reports unknown rather than closed', () {
    test('null and empty hours', () {
      expect(CafeOpenStatus.resolve(null).state, CafeOpenState.unknown);
      expect(CafeOpenStatus.resolve({}).state, CafeOpenState.unknown);
    });

    test('a zero-length span is a placeholder, not a 24-hour cafe', () {
      // Coffee Bear and CBTL Garden Row store 00:00-00:00 for all seven days.
      expect(
        CafeOpenStatus.resolve(
          everyDay(day('00:00', '00:00')),
          now: manila(2026, 7, 21, 14),
        ).state,
        CafeOpenState.unknown,
      );
    });

    test('a malformed close time', () {
      // Wave Cafe stores "21:0020:00" for Saturday.
      final hours = {
        ...everyDay(day('11:00', '20:00')),
        'tuesday': day('10:00', '21:0020:00'),
      };
      expect(
        CafeOpenStatus.resolve(hours, now: manila(2026, 7, 21, 14)).state,
        CafeOpenState.unknown,
      );
    });

    test('an empty close time', () {
      // The High Grounds Coffee stores an empty close for Wednesday with
      // closed:false, so it is neither a rest day nor a usable span.
      final hours = {
        ...everyDay(day('10:00', '20:00')),
        'wednesday': day('10:00', ''),
      };
      expect(
        CafeOpenStatus.resolve(hours, now: manila(2026, 7, 22, 14)).state,
        CafeOpenState.unknown,
      );
    });

    test('out-of-range times', () {
      expect(
        CafeOpenStatus.resolve(
          everyDay(day('25:00', '30:00')),
          now: manila(2026, 7, 21, 14),
        ).state,
        CafeOpenState.unknown,
      );
    });
  });

  group('time zone', () {
    // 2026-07-22 00:30 UTC is already 08:30 Wednesday in Manila. Resolving in
    // the device zone would read Tuesday's row, and for a viewer far enough
    // west, the wrong day entirely.
    final hours = {
      ...everyDay(closedDay),
      'wednesday': day('8:00', '18:00'),
    };

    test('resolves the day and time in Manila, not UTC', () {
      expect(
        CafeOpenStatus.resolve(
          hours,
          now: DateTime.utc(2026, 7, 22, 0, 30),
        ).state,
        CafeOpenState.open,
      );
    });

    test('gives the same answer for the same instant in another zone', () {
      final instant = DateTime.utc(2026, 7, 22, 0, 30);
      expect(
        CafeOpenStatus.resolve(hours, now: instant.toLocal()).state,
        CafeOpenStatus.resolve(hours, now: instant).state,
      );
    });
  });
}
