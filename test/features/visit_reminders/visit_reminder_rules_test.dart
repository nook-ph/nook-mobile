import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/visit_reminders/domain/visit_reminder_rules.dart';

void main() {
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 10, day, hour, minute);

  PendingVisitReminder pending(String cafeId, DateTime fireAt) =>
      PendingVisitReminder(
        id: visitReminderIdFor(cafeId),
        cafeId: cafeId,
        cafeName: cafeId,
        fireAt: fireAt,
      );

  group('deliveryTime', () {
    test('90 minutes after the tap, inside the window', () {
      expect(VisitReminderRules.deliveryTime(at(16, 12)), at(16, 13, 30));
    });

    test('the last minute before 21:00 still counts', () {
      expect(VisitReminderRules.deliveryTime(at(16, 19, 29)), at(16, 20, 59));
    });

    test('landing at 21:00 or later moves to 10:00 the next day', () {
      expect(VisitReminderRules.deliveryTime(at(16, 19, 30)), at(17, 10));
      expect(VisitReminderRules.deliveryTime(at(16, 23, 50)), at(17, 10));
    });

    test('landing before 09:00 waits for 10:00 the same day', () {
      expect(VisitReminderRules.deliveryTime(at(17, 1)), at(17, 10));
      expect(VisitReminderRules.deliveryTime(at(17, 7)), at(17, 10));
    });

    test('a slot more than 18 h after the tap is dropped', () {
      // Only reachable with a long delay; the 90-minute one never is.
      expect(
        VisitReminderRules.deliveryTime(
          at(16, 14),
          delayOverride: const Duration(hours: 8),
        ),
        isNull,
      );
      expect(
        VisitReminderRules.deliveryTime(
          at(16, 17),
          delayOverride: const Duration(hours: 5),
        ),
        at(17, 10),
      );
    });

    test('the window is 09:00 up to, not including, 21:00', () {
      expect(VisitReminderRules.inWindow(at(16, 9)), isTrue);
      expect(VisitReminderRules.inWindow(at(16, 8, 59)), isFalse);
      expect(VisitReminderRules.inWindow(at(16, 20, 59)), isTrue);
      expect(VisitReminderRules.inWindow(at(16, 21)), isFalse);
    });
  });

  group('plan', () {
    test('schedules with nothing pending', () {
      final plan = VisitReminderRules.plan(
        cafeId: 'a',
        now: at(16, 12),
        pending: const [],
      );
      expect(plan, ReminderPlan.schedule(at(16, 13, 30)));
    });

    test('a second tap on the same cafe replaces its reminder', () {
      final old = pending('a', at(16, 13, 30));
      final plan = VisitReminderRules.plan(
        cafeId: 'a',
        now: at(16, 13),
        pending: [old],
      );
      expect(plan.fireAt, at(16, 14, 30));
      expect(plan.replace, [old]);
    });

    test('another cafe on the same day is replaced: one a day', () {
      final other = pending('b', at(16, 13, 30));
      final plan = VisitReminderRules.plan(
        cafeId: 'a',
        now: at(16, 12, 30),
        pending: [other],
      );
      expect(plan.fireAt, at(16, 14));
      expect(plan.replace, [other]);
    });

    test('another cafe on a different day is left alone', () {
      final tomorrow = pending('b', at(17, 10));
      final plan = VisitReminderRules.plan(
        cafeId: 'a',
        now: at(16, 12),
        pending: [tomorrow],
      );
      expect(plan.fireAt, at(16, 13, 30));
      expect(plan.replace, isEmpty);
    });

    test('no second reminder on a day one already went out', () {
      final plan = VisitReminderRules.plan(
        cafeId: 'a',
        now: at(16, 15),
        pending: const [],
        lastDeliveredDay: at(16, 11),
      );
      expect(plan, const ReminderPlan.skip(ReminderSkipReason.dailyCap));
    });

    test('a reminder delivered yesterday does not block today', () {
      final plan = VisitReminderRules.plan(
        cafeId: 'a',
        now: at(16, 15),
        pending: const [],
        lastDeliveredDay: at(15, 20),
      );
      expect(plan.fireAt, at(16, 16, 30));
    });

    test('a late-night tap deferred to tomorrow checks tomorrow', () {
      // Delivered today at 11:00; the 22:00 tap lands tomorrow at 10:00.
      final plan = VisitReminderRules.plan(
        cafeId: 'a',
        now: at(16, 22),
        pending: const [],
        lastDeliveredDay: at(16, 11),
      );
      expect(plan.fireAt, at(17, 10));
    });

    test('a dropped slot skips as outside the window', () {
      final plan = VisitReminderRules.plan(
        cafeId: 'a',
        now: at(16, 14),
        pending: const [],
        delayOverride: const Duration(hours: 8),
      );
      expect(plan, const ReminderPlan.skip(ReminderSkipReason.outsideWindow));
    });
  });

  group('sweep', () {
    test('drops reminders that went out and keeps the latest day', () {
      final gone = pending('a', at(16, 11));
      final coming = pending('b', at(17, 10));
      final swept = VisitReminderRules.sweep([gone, coming], at(16, 12), null);
      expect(swept.upcoming, [coming]);
      expect(swept.lastDelivered, at(16, 11));
    });

    test('keeps an older delivery day when nothing new went out', () {
      final swept = VisitReminderRules.sweep(const [], at(16, 12), at(15, 10));
      expect(swept.lastDelivered, at(15, 10));
    });
  });

  group('prePromptBlock', () {
    PrePromptSkipReason? block({
      List<DateTime> shown = const [],
      NotificationPermission permission = NotificationPermission.notAsked,
      bool enabled = true,
      bool holdout = false,
    }) => VisitReminderRules.prePromptBlock(
      now: at(16, 12),
      shownAt: shown,
      permission: permission,
      remindersEnabled: enabled,
      holdout: holdout,
    );

    test('first time: no block', () => expect(block(), isNull));

    test('never once granted or blocked', () {
      expect(
        block(permission: NotificationPermission.granted),
        PrePromptSkipReason.granted,
      );
      expect(
        block(permission: NotificationPermission.blocked),
        PrePromptSkipReason.blocked,
      );
    });

    test('never after visit reminders were turned off in Settings', () {
      expect(block(enabled: false), PrePromptSkipReason.disabled);
    });

    test('never in the holdout', () {
      expect(block(holdout: true), PrePromptSkipReason.holdout);
    });

    test('at least 7 days apart', () {
      expect(
        block(shown: [DateTime(2026, 10, 9, 12, 1)]),
        PrePromptSkipReason.gap,
      );
      expect(block(shown: [DateTime(2026, 10, 9, 12)]), isNull);
    });

    test('the gap counts from the latest ask, in any order', () {
      expect(
        block(shown: [DateTime(2026, 10, 15), DateTime(2026, 9, 1)]),
        PrePromptSkipReason.gap,
      );
    });

    test('at most 3 ever', () {
      final three = [
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 20),
        DateTime(2026, 9, 10),
      ];
      expect(block(shown: three), PrePromptSkipReason.cap);
      expect(block(shown: three.take(2).toList()), isNull);
    });
  });

  group('opening hours', () {
    test('open, or no readable hours: counts from the tap', () {
      expect(
        VisitReminderRules.visitStart(at(16, 12), const CafeOpenAtTap.open()),
        at(16, 12),
      );
      expect(
        VisitReminderRules.visitStart(at(16, 12), CafeOpenAtTap.unknown),
        at(16, 12),
      );
    });

    test('closed, opening before the send time: counts from opening', () {
      final open = CafeOpenAtTap.closed(opensAt: at(16, 8));
      final plan = VisitReminderRules.plan(
        cafeId: 'a',
        now: at(16, 7, 30),
        pending: const [],
        open: open,
      );
      // 8:00 + 90 min = 9:30, inside the window.
      expect(plan.fireAt, at(16, 9, 30));
    });

    test('closed, opening early: the window still holds', () {
      final plan = VisitReminderRules.plan(
        cafeId: 'a',
        now: at(16, 6),
        pending: const [],
        open: CafeOpenAtTap.closed(opensAt: at(16, 7)),
      );
      // 7:00 + 90 = 8:30, before 09:00: moved to 10:00.
      expect(plan.fireAt, at(16, 10));
    });

    test('closed, opening at or after the send time: no reminder', () {
      for (final open in [
        CafeOpenAtTap.closed(opensAt: at(16, 13, 30)),
        CafeOpenAtTap.closed(opensAt: at(17, 8)),
        const CafeOpenAtTap.closed(),
      ]) {
        final plan = VisitReminderRules.plan(
          cafeId: 'a',
          now: at(16, 12),
          pending: const [],
          open: open,
        );
        expect(plan, const ReminderPlan.skip(ReminderSkipReason.closed));
      }
    });

    test('a night tap to a cafe that opens tomorrow gets nothing', () {
      final plan = VisitReminderRules.plan(
        cafeId: 'a',
        now: at(16, 20),
        pending: const [],
        open: CafeOpenAtTap.closed(opensAt: at(17, 7)),
      );
      expect(plan.skipReason, ReminderSkipReason.closed);
    });

    test('read from operating_hours on the Manila clock', () {
      final hours = {
        for (final d in const [
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
          'saturday',
          'sunday',
        ])
          d: {'open': '08:00', 'close': '20:00'},
      };
      // 07:30 in Manila is 23:30 UTC the day before.
      final early = DateTime.utc(2026, 10, 15, 23, 30);
      expect(
        CafeOpenAtTap.fromHours(hours, early),
        CafeOpenAtTap.closed(opensAt: early.add(const Duration(minutes: 30))),
      );
      expect(
        CafeOpenAtTap.fromHours(hours, DateTime.utc(2026, 10, 16, 4)),
        const CafeOpenAtTap.open(),
      );
      expect(CafeOpenAtTap.fromHours(const {}, early), CafeOpenAtTap.unknown);
      expect(CafeOpenAtTap.unknown.wire, 'unknown');
    });
  });

  group("Didn't go", () {
    test('the second in a row pauses for 30 days and starts over', () {
      final first = VisitReminderRules.afterDidntGo(0, at(16, 12));
      expect(first, (misses: 1, pausedUntil: null));
      final second = VisitReminderRules.afterDidntGo(1, at(18, 12));
      expect(second.misses, 0);
      expect(second.pausedUntil, at(18, 12).add(const Duration(days: 30)));
    });

    test('a paused cafe gets nothing until the pause ends', () {
      final until = at(30, 12);
      expect(
        VisitReminderRules.plan(
          cafeId: 'a',
          now: at(16, 12),
          pending: const [],
          pausedUntil: until,
        ).skipReason,
        ReminderSkipReason.paused,
      );
      expect(
        VisitReminderRules.plan(
          cafeId: 'a',
          now: until,
          pending: const [],
          pausedUntil: until,
        ).fireAt,
        isNotNull,
      );
    });
  });

  group('holdout', () {
    test('stable per install and about 10% of installs', () {
      expect(
        VisitReminderRules.holdoutArm('abc'),
        VisitReminderRules.holdoutArm('abc'),
      );
      var holdout = 0;
      for (var i = 0; i < 10000; i++) {
        if (VisitReminderRules.holdoutArm('install-$i') == HoldoutArm.holdout) {
          holdout++;
        }
      }
      expect(holdout, inInclusiveRange(800, 1200));
    });
  });

  group('permissionFrom', () {
    NotificationPermission from({
      bool enabled = false,
      bool isIOS = false,
      int asks = 0,
      bool everGranted = false,
      bool instant = false,
    }) => VisitReminderRules.permissionFrom(
      enabled: enabled,
      isIOS: isIOS,
      systemAsks: asks,
      everGranted: everGranted,
      lastAskInstant: instant,
    );

    test('on is granted', () {
      expect(from(enabled: true), NotificationPermission.granted);
    });

    test('Android: askable until refused twice', () {
      expect(from(), NotificationPermission.notAsked);
      expect(from(asks: 1), NotificationPermission.notAsked);
      expect(from(asks: 2), NotificationPermission.blocked);
    });

    test('iOS: one refusal is final', () {
      expect(from(isIOS: true), NotificationPermission.notAsked);
      expect(from(isIOS: true, asks: 1), NotificationPermission.blocked);
    });

    test('turned off after a grant, or refused with no dialog: blocked', () {
      expect(from(everGranted: true), NotificationPermission.blocked);
      expect(from(asks: 1, instant: true), NotificationPermission.blocked);
    });
  });

  test('notification ids are stable, positive and differ by cafe', () {
    final a = visitReminderIdFor('3f2a-cafe');
    expect(a, visitReminderIdFor('3f2a-cafe'));
    expect(a, greaterThan(0));
    expect(a, lessThanOrEqualTo(0x7FFFFFFF));
    expect(a, isNot(visitReminderIdFor('3f2b-cafe')));
  });
}
