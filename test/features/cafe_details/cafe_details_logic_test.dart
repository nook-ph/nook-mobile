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
    // 2026-10-01 is a Thursday.
    final morning = DateTime(2026, 10, 1, 9, 30);

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
        DateTime(2026, 10, 1, 6, 0),
      );

      expect(status.isOpen, isFalse);
      expect(status.label, 'Closed');
      expect(status.shortDetail, 'opens 7:30 AM');
      expect(status.rowDetail, 'Opens 7:30 AM');
    });

    test('treats a closing time before the opening time as overnight', () {
      final hours = _week('18:00', '02:00');

      expect(
        CafeOpenStatus.resolve(hours, DateTime(2026, 10, 1, 23, 0)).isOpen,
        isTrue,
      );
      expect(
        CafeOpenStatus.resolve(hours, DateTime(2026, 10, 1, 1, 0)).isOpen,
        isTrue,
      );
      expect(
        CafeOpenStatus.resolve(hours, DateTime(2026, 10, 1, 12, 0)).isOpen,
        isFalse,
      );
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

    testWidgets('keeps the score out of the Been pill', (tester) async {
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

      expect(find.text('Been'), findsOneWidget);
      expect(find.text('Want to Try'), findsOneWidget);
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
