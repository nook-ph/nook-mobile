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

  group('canShowPrePrompt', () {
    bool can({
      List<DateTime> shown = const [],
      NotificationPermission permission = NotificationPermission.notAsked,
      bool enabled = true,
      DateTime? now,
    }) => VisitReminderRules.canShowPrePrompt(
      now: now ?? at(16, 12),
      shownAt: shown,
      permission: permission,
      remindersEnabled: enabled,
    );

    test('first time: yes', () => expect(can(), isTrue));

    test('never once granted or blocked', () {
      expect(can(permission: NotificationPermission.granted), isFalse);
      expect(can(permission: NotificationPermission.blocked), isFalse);
    });

    test('never after visit reminders were turned off in Settings', () {
      expect(can(enabled: false), isFalse);
    });

    test('at least 7 days apart', () {
      final last = DateTime(2026, 10, 9, 12, 1);
      expect(can(shown: [last]), isFalse);
      expect(can(shown: [DateTime(2026, 10, 9, 12)]), isTrue);
    });

    test('the gap counts from the latest ask, in any order', () {
      expect(
        can(shown: [DateTime(2026, 10, 15), DateTime(2026, 9, 1)]),
        isFalse,
      );
    });

    test('at most 3 ever', () {
      final three = [
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 20),
        DateTime(2026, 9, 10),
      ];
      expect(can(shown: three), isFalse);
      expect(can(shown: three.take(2).toList()), isTrue);
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
