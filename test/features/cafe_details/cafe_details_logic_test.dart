import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/presentation/widgets/cafe_status_control.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_open_status.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_tag_groups.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info_header.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_preview_section.dart';

Map<String, dynamic> _week(String open, String close) => {
  for (final day in CafeOpenStatus.orderedDays)
    day: {'open': open, 'close': close},
};

TagEntity _tag(String id, String name, [String? category]) =>
    TagEntity(id: id, name: name, category: category);

void main() {
  group('CafeOpenStatus', () {
    // 2026-10-01 is a Thursday. Hours are Manila wall-clock times (UTC+8),
    // so the instant is built from UTC and reads the same in any zone.
    DateTime manila(int day, int hour, int minute) => DateTime.utc(
      2026,
      10,
      day,
      hour,
      minute,
    ).subtract(const Duration(hours: 8));
    final morning = manila(1, 9, 30);

    test('is open inside today\'s hours, with the closing time', () {
      final status = CafeOpenStatus.resolve(_week('07:00', '22:00'), morning);

      expect(status.hasAnyHours, isTrue);
      expect(status.isOpen, isTrue);
      expect(status.label, 'Open');
      expect(status.shortDetail, 'until 10 PM');
      expect(status.rowDetail, 'Closes 10:00 PM');
    });

    test('is closed outside today\'s hours, with the opening time', () {
      final status = CafeOpenStatus.resolve(
        _week('07:30', '22:00'),
        manila(1, 6, 0),
      );

      expect(status.isOpen, isFalse);
      expect(status.label, 'Closed');
      expect(status.shortDetail, 'opens 7:30 AM');
      expect(status.rowDetail, 'Opens 7:30 AM');
    });

    test('treats a closing time before the opening time as overnight', () {
      final hours = _week('18:00', '02:00');

      expect(CafeOpenStatus.resolve(hours, manila(1, 23, 0)).isOpen, isTrue);
      expect(CafeOpenStatus.resolve(hours, manila(1, 1, 0)).isOpen, isTrue);
      expect(CafeOpenStatus.resolve(hours, manila(1, 12, 0)).isOpen, isFalse);
    });

    test('a day without hours is closed with no time to show', () {
      final hours = _week('07:00', '22:00')..remove('thursday');
      final status = CafeOpenStatus.resolve(hours, morning);

      expect(status.hasAnyHours, isTrue);
      expect(status.isOpen, isFalse);
      expect(status.shortDetail, isNull);
      expect(status.rowDetail, isNull);
      expect(CafeOpenStatus.formatRange(hours, 'thursday'), 'Closed');
    });

    test('a listing with no hours at all makes no claim', () {
      expect(CafeOpenStatus.resolve(const {}, morning).hasAnyHours, isFalse);
      expect(
        CafeOpenStatus.resolve(const {
          'monday': {'open': '', 'close': ''},
        }, morning).hasAnyHours,
        isFalse,
      );
    });

    test('picks the right key for each weekday', () {
      expect(CafeOpenStatus.dayKey(DateTime(2026, 10, 1)), 'thursday');
      expect(CafeOpenStatus.dayKey(DateTime(2026, 10, 4)), 'sunday');
      expect(CafeOpenStatus.dayKey(DateTime(2026, 10, 5)), 'monday');
    });

    test('formats times and ranges', () {
      expect(CafeOpenStatus.formatTime(0), '12:00 AM');
      expect(CafeOpenStatus.formatTime(12 * 60 + 5), '12:05 PM');
      expect(CafeOpenStatus.formatTimeShort(22 * 60), '10 PM');
      expect(CafeOpenStatus.formatTimeShort(21 * 60 + 30), '9:30 PM');
      expect(
        CafeOpenStatus.formatRange(_week('07:00', '22:00'), 'monday'),
        '7:00 AM – 10:00 PM',
      );
    });

    group('overnight hours on only some days', () {
      // Drip and Draft: Friday and Saturday 7:00-2:00, the rest 7:00-22:00.
      // 2026-10-02 is a Friday, the 4th a Sunday.
      final hours = {
        ..._week('7:00', '22:00'),
        'friday': {'open': '7:00', 'close': '2:00'},
        'saturday': {'open': '7:00', 'close': '2:00'},
      };

      test('Sunday 01:00 is open on Saturday\'s span, until 2 AM', () {
        final status = CafeOpenStatus.resolve(hours, manila(4, 1, 0));

        expect(status.isOpen, isTrue);
        expect(status.shortDetail, 'until 2 AM');
        expect(status.rowDetail, 'Closes 2:00 AM');
        expect(status.minutesUntilChange, 60);
      });

      test('Friday 01:00 is closed: Thursday shut at 10 PM', () {
        final status = CafeOpenStatus.resolve(hours, manila(2, 1, 0));

        expect(status.isOpen, isFalse);
        expect(status.barText, 'Closed · opens 7 AM');
      });

      test('Saturday 01:40 closes soon, counted across midnight', () {
        final status = CafeOpenStatus.resolve(hours, manila(3, 1, 40));

        expect(status.closesSoon, isTrue);
        expect(status.barText, 'Closes 2 AM · in 20 min');
      });
    });

    group('the next opening', () {
      // Closed on Mondays, like nine of the listed cafes.
      final hours = {
        ..._week('07:00', '22:00'),
        'monday': {'open': '', 'close': '', 'closed': true},
      };

      test('after closing it is tomorrow\'s, and says so', () {
        final status = CafeOpenStatus.resolve(hours, manila(1, 23, 0));

        expect(status.shortDetail, 'opens 7 AM tomorrow');
        expect(status.rowDetail, 'Opens 7:00 AM tomorrow');
        expect(status.barText, 'Closed · opens 7 AM tomorrow');
      });

      test('Sunday night skips the closed Monday', () {
        final status = CafeOpenStatus.resolve(hours, manila(4, 23, 0));

        expect(status.isOpen, isFalse);
        expect(status.shortDetail, 'opens 7 AM Tuesday');
        expect(status.rowDetail, 'Opens 7:00 AM Tuesday');
        expect(status.opensSoon, isFalse);
      });

      test('the closed day itself shows no time', () {
        final status = CafeOpenStatus.resolve(hours, manila(5, 12, 0));

        expect(status.isOpen, isFalse);
        expect(status.label, 'Closed');
        expect(status.shortDetail, isNull);
        expect(CafeOpenStatus.formatRange(hours, 'monday'), 'Closed');
      });

      test('an opening just past midnight is still "soon"', () {
        final late = {..._week('00:10', '18:00')};
        final status = CafeOpenStatus.resolve(late, manila(1, 23, 50));

        expect(status.opensSoon, isTrue);
        expect(status.minutesUntilChange, 20);
        expect(status.barText, 'Opens 12:10 AM · in 20 min');
      });
    });

    group('agrees with the cards\' resolver', () {
      test('"9:30" and "09:30" are the same time', () {
        for (final open in ['9:30', '09:30']) {
          final hours = _week(open, '21:00');
          expect(
            CafeOpenStatus.resolve(hours, manila(1, 9, 29)).isOpen,
            isFalse,
            reason: open,
          );
          final status = CafeOpenStatus.resolve(hours, manila(1, 9, 30));
          expect(status.isOpen, isTrue, reason: open);
          expect(
            CafeOpenStatus.formatRange(hours, 'thursday'),
            '9:30 AM – 9:00 PM',
            reason: open,
          );
        }
      });

      test('00:00-00:00 all week is a placeholder: no claim at all', () {
        final status = CafeOpenStatus.resolve(
          _week('00:00', '00:00'),
          manila(1, 12, 0),
        );

        expect(status.hasAnyHours, isFalse);
        expect(status.isOpen, isFalse);
      });

      test('a malformed or empty close is not read as a time', () {
        final hours = {
          ..._week('10:00', '20:00'),
          'thursday': {'open': '10:00', 'close': '21:0020:00'},
          'friday': {'open': '10:00', 'close': ''},
        };

        expect(
          CafeOpenStatus.resolve(hours, manila(1, 21, 10)).isOpen,
          isFalse,
        );
        expect(CafeOpenStatus.hoursFor(hours, 'thursday'), isNull);
        expect(CafeOpenStatus.hoursFor(hours, 'friday'), isNull);
      });

      test('the day and hour are Manila\'s, whatever the instant\'s zone', () {
        final hours = {
          'friday': {'open': '08:00', 'close': '18:00'},
        };
        // 00:30 UTC on Friday the 2nd is 08:30 on Friday in Manila.
        final instant = DateTime.utc(2026, 10, 2, 0, 30);

        expect(CafeOpenStatus.resolve(hours, instant).isOpen, isTrue);
        expect(CafeOpenStatus.resolve(hours, instant.toLocal()).isOpen, isTrue);
        // 17:30 UTC on Thursday is already 01:30 on Friday there.
        expect(
          CafeOpenStatus.todayKey(DateTime.utc(2026, 10, 1, 17, 30)),
          'friday',
        );
      });

      test('uses the same closing-soon threshold', () {
        expect(CafeOpenStatus.soonThreshold, 30);
      });
    });
  });

  group('CafeTagGroups', () {
    test('splits tags by category, however the category is spelled', () {
      final groups = CafeTagGroups.from([
        _tag('1', 'Free WiFi', 'Amenities'),
        _tag('2', 'Solo Work', 'best_for'),
        _tag('3', 'Cash', 'Payment Options'),
      ]);

      expect(groups.amenities.map((t) => t.name), ['Free WiFi']);
      expect(groups.bestFor.map((t) => t.name), ['Solo Work']);
      expect(groups.payments.map((t) => t.name), ['Cash']);
    });

    test('finds payment tags by name when none are categorised', () {
      final groups = CafeTagGroups.from([
        _tag('1', 'Free WiFi', 'amenities'),
        _tag('2', 'GCash'),
        _tag('3', 'Date Spot', 'best for'),
      ]);

      expect(groups.payments.map((t) => t.name), ['GCash']);
      expect(groups.bestFor.map((t) => t.name), ['Date Spot']);
    });

    test('uncategorised tags fall back to best for', () {
      final groups = CafeTagGroups.from([
        _tag('1', 'Free WiFi', 'amenities'),
        _tag('2', 'Cash'),
        _tag('3', 'Quiet'),
      ]);

      expect(groups.bestFor.map((t) => t.name), ['Quiet']);
    });

    test('is empty for a listing with no tags', () {
      final groups = CafeTagGroups.from(const []);

      expect(groups.amenities, isEmpty);
      expect(groups.bestFor, isEmpty);
      expect(groups.payments, isEmpty);
    });
  });

  group('ReviewDistribution', () {
    test('counts each rating and averages them', () {
      final distribution = ReviewDistribution.from([5, 5, 4, 3, 5]);

      expect(distribution.total, 5);
      expect(distribution.countFor(5), 3);
      expect(distribution.countFor(4), 1);
      expect(distribution.countFor(1), 0);
      expect(distribution.fractionFor(5), closeTo(0.6, 1e-9));
      expect(distribution.average, closeTo(4.4, 1e-9));
    });

    test('ignores ratings outside one to five', () {
      final distribution = ReviewDistribution.from([0, 6, 4]);

      expect(distribution.total, 1);
      expect(distribution.average, 4);
    });

    test('is all zeroes with no reviews', () {
      final distribution = ReviewDistribution.from(const []);

      expect(distribution.total, 0);
      expect(distribution.average, 0);
      expect(distribution.fractionFor(5), 0);
    });
  });

  test('header location joins what the listing has', () {
    expect(
      CafeInfoHeader.locationText('Lahug', 'Cebu City'),
      'Lahug, Cebu City',
    );
    expect(CafeInfoHeader.locationText('  ', 'Cebu City'), 'Cebu City');
    expect(CafeInfoHeader.locationText('', ''), '');
  });

  group('CafeStatusControl in fill mode', () {
    Widget host(Widget child, {double width = 346}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

    testWidgets('gives the two pills equal halves of the row', (tester) async {
      await tester.pumpWidget(
        host(
          CafeStatusControl(
            fill: true,
            status: CafeStatus.none,
            onTapBeen: () {},
            onTapWantToTry: () {},
          ),
        ),
      );

      final been = tester.getSize(find.bySemanticsLabel('Been'));
      final want = tester.getSize(find.bySemanticsLabel('Want to Try'));
      expect(been.width, want.width);
      expect(been.width, closeTo((346 - 8) / 2, 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a ranked Been pill carries the score, not the rank', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          CafeStatusControl(
            fill: true,
            status: CafeStatus.been,
            score: '8.7',
            rankLabel: '#3 of 12',
            onTapBeen: () {},
            onTapWantToTry: () {},
          ),
        ),
      );

      expect(find.text('Been · 8.7'), findsOneWidget);
      expect(find.text('Want to Try'), findsOneWidget);
      expect(find.textContaining('#3 of 12'), findsNothing);
      // Still announced by its name.
      expect(find.bySemanticsLabel('Been'), findsOneWidget);
    });

    testWidgets('the score stays off the pill until the cafe is Been', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          CafeStatusControl(
            fill: true,
            status: CafeStatus.wantToTry,
            score: '8.7',
            onTapBeen: () {},
            onTapWantToTry: () {},
          ),
        ),
      );

      expect(find.text('Been'), findsOneWidget);
      expect(find.textContaining('8.7'), findsNothing);
    });

    testWidgets('reports taps on each pill', (tester) async {
      var been = 0, want = 0;
      await tester.pumpWidget(
        host(
          CafeStatusControl(
            fill: true,
            status: CafeStatus.none,
            onTapBeen: () => been++,
            onTapWantToTry: () => want++,
          ),
        ),
      );

      await tester.tap(find.text('Been'));
      await tester.tap(find.text('Want to Try'));
      expect((been, want), (1, 1));
    });
  });
}
