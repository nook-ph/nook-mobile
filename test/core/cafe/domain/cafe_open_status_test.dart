import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/cafe_open_status.dart';

/// Manila is a fixed UTC+8, so a UTC instant plus 8 hours is the wall-clock
/// time the cafe's hours are written in. Tests pass UTC instants and name the
/// Manila time they correspond to.
DateTime manila(int year, int month, int day, int hour, [int minute = 0]) =>
    DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
    ).subtract(const Duration(hours: 8));

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
      final status = CafeOpenStatus.resolve(elim, now: manila(2026, 7, 22, 1));
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
      final hours = {...everyDay(day('18:00', '2:00')), 'wednesday': closedDay};
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
    final hours = {...everyDay(closedDay), 'wednesday': day('8:00', '18:00')};

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

    test('manilaNow reads the Manila clock and weekday', () {
      final manilaTime = CafeOpenStatus.manilaNow(
        DateTime.utc(2026, 7, 21, 17, 30),
      );
      // 17:30 UTC on Tuesday is 01:30 on Wednesday in Manila.
      expect(manilaTime.weekday, DateTime.wednesday);
      expect(manilaTime.hour, 1);
      expect(manilaTime.minute, 30);
    });
  });

  group('overnight hours on only some days', () {
    // Drip and Draft: Friday and Saturday 7:00-2:00, the rest 7:00-22:00.
    // 2026-07-24 is a Friday, the 25th a Saturday, the 26th a Sunday.
    final hours = {
      ...everyDay(day('7:00', '22:00')),
      'friday': day('7:00', '2:00'),
      'saturday': day('7:00', '2:00'),
    };

    test('Sunday 01:00 is still open on Saturday\'s span', () {
      final status = CafeOpenStatus.resolve(hours, now: manila(2026, 7, 26, 1));
      expect(status.state, CafeOpenState.open);
      expect(status.minutesUntilClose, 60);
      expect(status.closesAtMinutes, 2 * 60);
    });

    test('Friday 01:00 is closed: Thursday did not run past midnight', () {
      final status = CafeOpenStatus.resolve(hours, now: manila(2026, 7, 24, 1));
      expect(status.state, CafeOpenState.closed);
      expect(status.nextOpening!.dayOffset, 0);
      expect(status.nextOpening!.openMinutes, 7 * 60);
      expect(status.nextOpening!.minutesFromNow, 6 * 60);
    });

    test('Friday 23:00 is open until 2 AM', () {
      final status = CafeOpenStatus.resolve(
        hours,
        now: manila(2026, 7, 24, 23),
      );
      expect(status.state, CafeOpenState.open);
      expect(status.minutesUntilClose, 3 * 60);
      expect(status.closesAtMinutes, 2 * 60);
    });

    test('Sunday 02:00 sharp is closed', () {
      expect(
        CafeOpenStatus.resolve(hours, now: manila(2026, 7, 26, 2)).state,
        CafeOpenState.closed,
      );
    });
  });

  group('how a time is written', () {
    test('"9:30" and "09:30" are the same time', () {
      for (final open in ['9:30', '09:30']) {
        final hours = everyDay(day(open, '21:00'));
        expect(CafeOpenStatus.hoursFor(hours, 'tuesday'), (
          open: 9 * 60 + 30,
          close: 21 * 60,
        ), reason: open);
        expect(
          CafeOpenStatus.resolve(hours, now: manila(2026, 7, 21, 9, 29)).state,
          CafeOpenState.closed,
          reason: open,
        );
        expect(
          CafeOpenStatus.resolve(hours, now: manila(2026, 7, 21, 9, 30)).state,
          CafeOpenState.open,
          reason: open,
        );
      }
    });

    test('hoursFor has nothing for rest, placeholder and unreadable days', () {
      final hours = {
        'monday': closedDay,
        'tuesday': day('00:00', '00:00'),
        'wednesday': day('10:00', '21:0020:00'),
        'thursday': day('10:00', ''),
        'friday': day('9', '17'),
      };
      for (final key in hours.keys) {
        expect(CafeOpenStatus.hoursFor(hours, key), isNull, reason: key);
      }
      expect(CafeOpenStatus.hoursFor(hours, 'saturday'), isNull);
      expect(CafeOpenStatus.hoursFor(null, 'monday'), isNull);
    });
  });

  group('midnight closes', () {
    test('"24:00" and "00:00" both close at midnight', () {
      for (final close in ['24:00', '00:00']) {
        final status = CafeOpenStatus.resolve(
          everyDay(day('14:00', close)),
          now: manila(2026, 7, 21, 23),
        );
        expect(status.state, CafeOpenState.open, reason: close);
        expect(status.minutesUntilClose, 60, reason: close);
        expect(status.closesAtMinutes, 0, reason: close);
      }
    });

    test('a span that meets the next day\'s at midnight carries on', () {
      final hours = {
        ...everyDay(closedDay),
        'tuesday': day('18:00', '24:00'),
        'wednesday': day('00:00', '2:00'),
      };
      final status = CafeOpenStatus.resolve(
        hours,
        now: manila(2026, 7, 21, 23, 45),
      );
      // Not "closing soon": the doors stay open until 2 AM.
      expect(status.state, CafeOpenState.open);
      expect(status.minutesUntilClose, 135);
      expect(status.closesAtMinutes, 2 * 60);
    });

    test('00:00-24:00 every day is open round the clock', () {
      final hours = everyDay(day('00:00', '24:00'));
      for (final now in [
        manila(2026, 7, 21, 0),
        manila(2026, 7, 21, 14),
        manila(2026, 7, 21, 23, 50),
      ]) {
        final status = CafeOpenStatus.resolve(hours, now: now);
        expect(status.state, CafeOpenState.open);
        // Never "closing soon": there is no close to count down to.
        expect(status.minutesUntilClose, isNull);
      }
    });

    test('00:00-00:00 is a placeholder at any hour, never open', () {
      final hours = everyDay(day('00:00', '00:00'));
      for (final now in [
        manila(2026, 7, 21, 0),
        manila(2026, 7, 21, 12),
        manila(2026, 7, 21, 23, 59),
      ]) {
        final status = CafeOpenStatus.resolve(hours, now: now);
        expect(status.state, CafeOpenState.unknown);
        expect(status.isOpen, isFalse);
        expect(status.nextOpening, isNull);
      }
    });
  });

  group('next opening', () {
    // Closed on Mondays. 2026-07-26 is a Sunday.
    final hours = {...everyDay(day('7:00', '22:00')), 'monday': closedDay};

    test('before opening it is today\'s', () {
      final next = CafeOpenStatus.resolve(
        hours,
        now: manila(2026, 7, 21, 6, 40),
      ).nextOpening!;
      expect(next.dayOffset, 0);
      expect(next.dayKey, 'tuesday');
      expect(next.minutesFromNow, 20);
    });

    test('after closing it is tomorrow\'s', () {
      final next = CafeOpenStatus.resolve(
        hours,
        now: manila(2026, 7, 21, 23),
      ).nextOpening!;
      expect(next.dayOffset, 1);
      expect(next.dayKey, 'wednesday');
      expect(next.openMinutes, 7 * 60);
      expect(next.minutesFromNow, 8 * 60);
    });

    test('a closed day is skipped, not opened at the usual time', () {
      final next = CafeOpenStatus.resolve(
        hours,
        now: manila(2026, 7, 26, 23),
      ).nextOpening!;
      expect(next.dayOffset, 2);
      expect(next.dayKey, 'tuesday');
    });

    test('on the closed day itself it is the next day that opens', () {
      final status = CafeOpenStatus.resolve(
        hours,
        now: manila(2026, 7, 27, 12),
      );
      expect(status.state, CafeOpenState.closed);
      expect(status.nextOpening!.dayOffset, 1);
      expect(status.nextOpening!.dayKey, 'tuesday');
    });

    test('a cafe open one day a week comes round to it again', () {
      final weekly = {...everyDay(closedDay), 'tuesday': day('8:00', '12:00')};
      final next = CafeOpenStatus.resolve(
        weekly,
        now: manila(2026, 7, 21, 13),
      ).nextOpening!;
      expect(next.dayOffset, 7);
      expect(next.dayKey, 'tuesday');
    });

    test('there is none while open, or when nothing opens', () {
      expect(
        CafeOpenStatus.resolve(hours, now: manila(2026, 7, 21, 12)).nextOpening,
        isNull,
      );
      expect(
        CafeOpenStatus.resolve(
          everyDay(closedDay),
          now: manila(2026, 7, 21, 12),
        ).nextOpening,
        isNull,
      );
    });
  });

  group('closing soon', () {
    final hours = everyDay(day('8:00', '22:00'));

    test('starts 30 minutes before closing', () {
      expect(
        CafeOpenStatus.resolve(hours, now: manila(2026, 7, 21, 21, 29)).state,
        CafeOpenState.open,
      );
      expect(
        CafeOpenStatus.resolve(hours, now: manila(2026, 7, 21, 21, 30)).state,
        CafeOpenState.closingSoon,
      );
    });
  });
}
