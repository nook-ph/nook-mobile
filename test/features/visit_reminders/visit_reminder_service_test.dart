import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/notification_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/presentation/session_ask_budget.dart';
import 'package:nook/features/visit_reminders/data/local_notifier.dart';
import 'package:nook/features/visit_reminders/data/visit_reminder_store.dart';
import 'package:nook/features/visit_reminders/domain/visit_reminder_rules.dart';
import 'package:nook/features/visit_reminders/presentation/visit_reminder_service.dart';
import 'package:nook/features/visit_reminders/presentation/widgets/notification_preprompt_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analytics/recording_analytics.dart';

class _FakeNotifier implements LocalNotifier {
  bool enabled = false;
  bool grant = true;
  int requests = 0;
  final Map<int, ({DateTime at, String title, String payload})> scheduled = {};
  final List<int> cancelled = [];
  void Function(NotificationTap tap)? onTap;
  NotificationTap? launch;

  @override
  Future<void> init({required void Function(NotificationTap) onTap}) async =>
      this.onTap = onTap;

  @override
  Future<NotificationTap?> launchTap() async => launch;

  bool muted = false;
  bool? openedChannel;

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<bool> channelMuted() async => muted;

  @override
  Future<bool> requestPermission() async {
    requests++;
    // Long enough to count as a dialog that was on screen.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    enabled = grant;
    return grant;
  }

  @override
  Future<void> openSettings({bool channel = false}) async =>
      openedChannel = channel;

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async => scheduled[id] = (at: at, title: title, payload: payload);

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

class _NoRepo implements ICafeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// An install id in the [arm] bucket.
String installIn(HoldoutArm arm) {
  for (var i = 0; ; i++) {
    if (VisitReminderRules.holdoutArm('install$i') == arm) return 'install$i';
  }
}

/// Every day the same hours, Manila wall clock.
Map<String, dynamic> _daily(String open, String close) => {
  for (final day in const [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ])
    day: {'open': open, 'close': close},
};

/// Cafe hours are Manila wall clock and the 09-21 window is the phone's;
/// the hours tests read 12:00 local as 12:00 Manila.
final Object notManila =
    DateTime(2026, 10, 16, 12).timeZoneOffset != const Duration(hours: 8)
    ? 'needs a UTC+8 host'
    : false;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNotifier notifier;
  late VisitReminderStore store;
  late RecordingAnalytics analytics;
  late DateTime clock;
  late CafeStatusCubit statuses;

  VisitReminderService make() => VisitReminderService(
    notifier: notifier,
    store: store,
    now: () => clock,
    isIOS: false,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'visitReminders.installId': installIn(HoldoutArm.ask),
    });
    notifier = _FakeNotifier();
    store = VisitReminderStore();
    analytics = RecordingAnalytics.install(addTearDown);
    clock = DateTime(2026, 10, 16, 12);
    statuses = CafeStatusCubit(
      getCafeStatusesUseCase: GetCafeStatusesUseCase(_NoRepo()),
      setCafeStatusUseCase: SetCafeStatusUseCase(_NoRepo()),
    );
    addTearDown(statuses.close);
  });

  Future<VisitReminderService> started() async {
    final service = make();
    await service.start(statuses: statuses);
    addTearDown(service.dispose);
    return service;
  }

  Future<DirectionsDecision> tap(
    VisitReminderService s,
    String id, {
    CafeStatus status = CafeStatus.none,
    Map<String, dynamic>? hours,
  }) => s.onDirectionsTap(
    cafeId: id,
    cafeName: 'Cafe $id',
    status: status,
    operatingHours: hours,
  );

  /// A Directions tap with permission already on, Maps opened.
  Future<void> directions(VisitReminderService s, String id) async {
    final decision = await tap(s, id);
    if (decision.scheduleOnLaunch) await s.confirmTrip();
  }

  String? skipReason() =>
      analytics.propertiesOf(NotificationEvents.prePromptSkipped)?['reason']
          as String?;

  test(
    'with permission, Directions schedules "Did you make it…?" 90 min on',
    () async {
      notifier.enabled = true;
      final service = await started();
      final decision = await tap(service, 'a');
      expect(decision.ask, isFalse);
      expect(decision.scheduleOnLaunch, isTrue);
      // Nothing until Maps has opened.
      expect(notifier.scheduled, isEmpty);
      await service.confirmTrip();

      final sent = notifier.scheduled[visitReminderIdFor('a')]!;
      expect(sent.at, clock.add(const Duration(minutes: 90)));
      expect(sent.title, 'Did you make it to Cafe a?');
      expect(sent.payload, 'a');
      expect(skipReason(), 'granted');
      expect(analytics.propertiesOf(NotificationEvents.postVisitScheduled), {
        'cafe_id': 'a',
        'delay_min': 90,
        'deferred': false,
        'replaced': 0,
        'cafe_open': 'unknown',
        'promised_at': sent.at.toUtc().toIso8601String(),
      });
    },
  );

  test('not asked yet: the ask is offered with the real time', () async {
    final service = await started();
    final decision = await tap(service, 'a');
    expect(decision.ask, isTrue);
    expect(decision.trip?.fireAt, clock.add(const Duration(minutes: 90)));
    expect(notifier.scheduled, isEmpty);
  });

  testWidgets('a spent session budget skips the ask, says why, and drops '
      'the trip', (tester) async {
    late VisitReminderService service;
    late DirectionsDecision decision;
    await tester.runAsync(() async {
      service = await started();
      decision = await tap(service, 'a');
    });
    expect(decision.ask, isTrue);
    SessionAskBudget.instance.spend(SessionAskKind.signUpAsk);
    addTearDown(SessionAskBudget.instance.resetForTest);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    analytics.events.clear();

    await tester.runAsync(
      () => VisitReminderPrompts.atDirections(context, service, decision),
    );

    expect(find.byType(BottomSheet), findsNothing);
    expect(analytics.propertiesOf(NotificationEvents.prePromptSkipped), {
      'cafe_id': 'a',
      'reason': 'session_budget',
    });
    expect(
      analytics.propertiesOf(NotificationEvents.postVisitSkipped)?['reason'],
      'no_permission',
    );
    expect(await tester.runAsync(store.readTrip), isNull);
  });

  testWidgets('a page gone before the ask drops the trip and spends nothing', (
    tester,
  ) async {
    late VisitReminderService service;
    late DirectionsDecision decision;
    await tester.runAsync(() async {
      service = await started();
      decision = await tap(service, 'a');
    });
    addTearDown(SessionAskBudget.instance.resetForTest);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    await tester.pumpWidget(const MaterialApp(home: Text('elsewhere')));
    analytics.events.clear();

    await tester.runAsync(
      () => VisitReminderPrompts.atDirections(context, service, decision),
    );

    expect(SessionAskBudget.instance.canShowSheet, isTrue);
    expect(analytics.names, isNot(contains(NotificationEvents.prePromptShown)));
    expect(await tester.runAsync(store.readTrip), isNull);
  });

  test('Remind me, then Allow, schedules at the promised time', () async {
    final service = await started();
    final decision = await tap(service, 'a');
    clock = clock.add(const Duration(seconds: 20));
    final granted = await service.requestPermission(
      trigger: NotificationPromptTrigger.directions,
    );
    expect(granted, isTrue);
    expect(notifier.scheduled.values.single.at, decision.trip!.fireAt);
    expect(await store.readTrip(), isNull);
    expect(analytics.propertiesOf(NotificationEvents.permissionResult), {
      'trigger': 'directions',
      'granted': true,
      'prompted': true,
    });
  });

  test('Deny drops the trip; nothing is scheduled', () async {
    notifier.grant = false;
    final service = await started();
    await tap(service, 'a');
    await service.requestPermission(
      trigger: NotificationPromptTrigger.directions,
    );
    expect(notifier.scheduled, isEmpty);
    expect(await store.readTrip(), isNull);
  });

  test('a trip survives the app being killed during the ask', () async {
    final first = await started();
    await tap(first, 'a');
    // Killed with the system dialog up; allowed from the phone's settings.
    notifier.enabled = true;
    final second = make();
    await second.start(statuses: statuses);
    addTearDown(second.dispose);
    expect(notifier.scheduled.keys, [visitReminderIdFor('a')]);
    expect(await store.readTrip(), isNull);
  });

  group('no ask when nothing would be sent', () {
    test(
      'closed at the tap and not opening in time',
      skip: notManila,
      () async {
        final service = await started();
        // 12:00 Manila; opens 16:00, after the 13:30 send time.
        final decision = await tap(
          service,
          'a',
          hours: _daily('16:00', '22:00'),
        );
        expect(decision.ask, isFalse);
        expect(decision.trip, isNull);
        expect(skipReason(), 'closed');
        expect(
          analytics.propertiesOf(
            NotificationEvents.postVisitSkipped,
          )?['reason'],
          'closed',
        );
      },
    );

    test('closed but opening first: 90 min from opening', () async {
      notifier.enabled = true;
      final service = await started();
      // 12:00 Manila; opens 13:00, before the 13:30 send time.
      final decision = await tap(service, 'a', hours: _daily('13:00', '22:00'));
      await service.confirmTrip();
      expect(decision.trip, isNotNull);
      expect(
        notifier.scheduled.values.single.at,
        DateTime(2026, 10, 16, 14, 30), // 13:00 + 90 min
      );
      expect(
        analytics.propertiesOf(
          NotificationEvents.postVisitScheduled,
        )?['cafe_open'],
        'opens_later',
      );
    }, skip: notManila);

    test('turned off in Settings', () async {
      notifier.enabled = true;
      final service = await started();
      await service.setEnabled(false);
      expect((await tap(service, 'a')).trip, isNull);
      expect(skipReason(), 'disabled');
    });

    test('already Been', () async {
      notifier.enabled = true;
      final service = await started();
      expect((await tap(service, 'a', status: CafeStatus.been)).trip, isNull);
      expect(skipReason(), 'already_been');
    });

    test('blocked: no ask, no reminder', () async {
      notifier.grant = false;
      final service = await started();
      await service.requestPermission(trigger: 'settings');
      await service.requestPermission(trigger: 'settings');
      expect(await service.permission(), NotificationPermission.blocked);
      expect((await tap(service, 'a')).ask, isFalse);
      expect(skipReason(), 'blocked');
    });

    test('a muted channel counts as blocked', () async {
      notifier.enabled = true;
      notifier.muted = true;
      final service = await started();
      expect(await service.permission(), NotificationPermission.blocked);
      expect(await service.channelMuted(), isTrue);
      expect((await tap(service, 'a')).trip, isNull);
      expect(skipReason(), 'blocked');
      await service.openSystemSettings();
      expect(notifier.openedChannel, isTrue);
    });

    test('once one went out today, no second today', () async {
      notifier.enabled = true;
      final service = await started();
      await directions(service, 'a');
      clock = clock.add(const Duration(hours: 3)); // a's has gone out
      notifier.scheduled.clear();
      expect((await tap(service, 'b')).trip, isNull);
      expect(skipReason(), 'daily_cap');
    });
  });

  group('the ask limits', () {
    test('capped at 3, 7 days apart', () async {
      final service = await started();
      for (var i = 0; i < 3; i++) {
        expect((await tap(service, 'a')).ask, isTrue);
        await service.recordPrePromptShown();
        await service.dropTrip();
        expect((await tap(service, 'a')).ask, isFalse);
        expect(skipReason(), i < 2 ? 'gap' : 'cap');
        clock = clock.add(const Duration(days: 7));
      }
      expect((await tap(service, 'a')).ask, isFalse);
      expect(skipReason(), 'cap');
    });

    test('the holdout never gets the ask, and the arm is logged', () async {
      SharedPreferences.setMockInitialValues({
        'visitReminders.installId': installIn(HoldoutArm.holdout),
      });
      final service = await started();
      await Future<void>.delayed(Duration.zero);
      expect(
        analytics.propertiesOf(
          NotificationEvents.notificationState,
        )?['holdout_arm'],
        'holdout',
      );
      expect((await tap(service, 'a')).ask, isFalse);
      expect(skipReason(), 'holdout');
    });

    test('a new install is bucketed once', () async {
      SharedPreferences.setMockInitialValues({});
      final service = await started();
      final arm = await service.holdoutArm();
      expect(await service.holdoutArm(), arm);
      expect(
        analytics.names.where((n) => n == NotificationEvents.holdoutAssigned),
        hasLength(1),
      );
    });
  });

  test('re-tapping Directions reschedules instead of stacking', () async {
    notifier.enabled = true;
    final service = await started();
    await directions(service, 'a');
    clock = clock.add(const Duration(minutes: 20));
    await directions(service, 'a');
    expect(notifier.scheduled.length, 1);
    expect(
      notifier.scheduled.values.single.at,
      clock.add(const Duration(minutes: 90)),
    );
    expect((await store.readPending()).length, 1);
  });

  test('a second cafe the same day replaces the first', () async {
    notifier.enabled = true;
    final service = await started();
    await directions(service, 'a');
    await directions(service, 'b');
    expect(notifier.scheduled.keys, [visitReminderIdFor('b')]);
    expect(notifier.cancelled, contains(visitReminderIdFor('a')));
  });

  test('marking the cafe Been before it fires cancels it', () async {
    notifier.enabled = true;
    final service = await started();
    await directions(service, 'a');
    statuses.showLocal({'a': CafeStatus.been});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.scheduled, isEmpty);
    expect(await store.readPending(), isEmpty);
    expect(
      analytics.propertiesOf(NotificationEvents.postVisitCancelled)?['reason'],
      'marked_been',
    );
  });

  test('a Been that fails to save does not cancel the reminder', () async {
    notifier.enabled = true;
    final service = await started();
    await directions(service, 'a');
    expect(notifier.scheduled, contains(visitReminderIdFor('a')));
    // Offline: the Been shows at once, then rolls back.
    expect(await statuses.set('a', CafeStatus.been), isFalse);
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(notifier.scheduled, contains(visitReminderIdFor('a')));
    expect([for (final p in await store.readPending()) p.cafeId], ['a']);
  });

  test(
    'marking Been after its reminder went out keeps the day counted',
    () async {
      notifier.enabled = true;
      final service = await started();
      await directions(service, 'a');
      // a's reminder has gone out (no resume swept it), then a is marked Been.
      clock = clock.add(const Duration(hours: 3));
      statuses.showLocal({'a': CafeStatus.been});
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(
        analytics.names,
        isNot(contains(NotificationEvents.postVisitCancelled)),
      );
      // A second cafe the same day gets no second reminder.
      clock = clock.add(const Duration(minutes: 30));
      expect((await tap(service, 'b')).trip, isNull);
    },
  );

  test('back-to-back status emissions cancel once, and a reminder '
      'scheduled meanwhile is kept', () async {
    notifier.enabled = true;
    final service = await started();
    // 'a' at 20:00 lands tomorrow at 10:00; 'b' at noon lands today, so
    // neither replaces the other.
    clock = DateTime(2026, 10, 16, 20);
    await directions(service, 'a');
    clock = DateTime(2026, 10, 16, 12);
    final decision = await tap(service, 'b');
    // A set emits twice (pending, then confirmed): both say 'a' is Been.
    statuses.showLocal({'a': CafeStatus.been});
    statuses.showLocal({'a': CafeStatus.been, 'z': CafeStatus.wantToTry});
    final scheduling = service.confirmTrip();
    expect(decision.scheduleOnLaunch, isTrue);
    await scheduling;
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(
      analytics.names.where((n) => n == NotificationEvents.postVisitCancelled),
      hasLength(1),
    );
    expect(notifier.scheduled.keys, [visitReminderIdFor('b')]);
    expect([for (final p in await store.readPending()) p.cafeId], ['b']);
  });

  test('app open logs the notification state', () async {
    notifier.enabled = true;
    notifier.muted = true;
    await started();
    await Future<void>.delayed(Duration.zero);
    expect(analytics.propertiesOf(NotificationEvents.notificationState), {
      'app_enabled': true,
      'channel_muted': true,
      'permission': 'blocked',
      'reminders_enabled': true,
      'holdout_arm': 'ask',
    });
  });

  group('taps on the notification', () {
    test('the body and I went both open the cafe as "I went"', () async {
      final service = await started();
      notifier.onTap!(const NotificationTap(payload: 'a'));
      expect(service.openRequests.value?.cafeId, 'a');
      expect(analytics.propertiesOf(NotificationEvents.postVisitOpened), {
        'cafe_id': 'a',
        'action': 'body',
      });
      service.openRequests.value = null;
      notifier.onTap!(
        const NotificationTap(
          payload: 'a',
          actionId: VisitReminderActions.went,
        ),
      );
      expect(service.openRequests.value?.cafeId, 'a');
      expect(analytics.propertiesOf(NotificationEvents.postVisitOpened), {
        'cafe_id': 'a',
        'action': 'went',
      });
    });

    test("Didn't go opens nothing and is logged", () async {
      final service = await started();
      notifier.onTap!(
        const NotificationTap(
          payload: 'a',
          actionId: VisitReminderActions.didntGo,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(service.openRequests.value, isNull);
      expect(analytics.names, contains(NotificationEvents.postVisitDidntGo));
    });

    test('a cold start from the notification is kept for the router', () async {
      notifier.launch = const NotificationTap(payload: 'a');
      final service = await started();
      expect(service.openRequests.value?.cafeId, 'a');
    });

    test(
      'a launch reported again (Android Recents) is not a new tap',
      () async {
        notifier.launch = NotificationTap(
          payload: 'a',
          actionId: VisitReminderActions.went,
          id: visitReminderIdFor('a'),
        );
        final first = await started();
        expect(first.openRequests.value?.cafeId, 'a');
        // The process died; Nook is reopened from Recents with the same
        // launch details.
        final again = await started();
        expect(again.openRequests.value, isNull);
      },
    );

    test(
      'a reminder scheduled again makes its next launch a new tap',
      () async {
        notifier.enabled = true;
        notifier.launch = NotificationTap(
          payload: 'a',
          actionId: VisitReminderActions.went,
          id: visitReminderIdFor('a'),
        );
        final first = await started();
        expect(first.openRequests.value?.cafeId, 'a');
        await tap(first, 'a');
        await first.confirmTrip();
        expect(notifier.scheduled, contains(visitReminderIdFor('a')));
        final next = await started();
        expect(next.openRequests.value?.cafeId, 'a');
      },
    );

    test("a background Didn't go is sent on the next start", () async {
      await VisitReminderStore.queueEvent({
        'event': 'didnt_go',
        'cafe_id': 'a',
        'at': clock.millisecondsSinceEpoch,
      });
      await started();
      expect(analytics.propertiesOf(NotificationEvents.postVisitDidntGo), {
        'cafe_id': 'a',
      });
    });

    test("two Didn't go in a row pause the cafe for 30 days", () async {
      notifier.enabled = true;
      for (var i = 0; i < 2; i++) {
        await VisitReminderStore.queueEvent({
          'event': 'didnt_go',
          'cafe_id': 'a',
          'at': clock.millisecondsSinceEpoch,
        });
      }
      final service = await started();
      expect(analytics.names, contains(NotificationEvents.postVisitPaused));
      expect((await tap(service, 'a')).trip, isNull);
      expect(skipReason(), 'paused');
      // Another cafe is not affected.
      expect((await tap(service, 'b')).trip, isNotNull);
      clock = clock.add(const Duration(days: 30, minutes: 1));
      expect((await tap(service, 'a')).trip, isNotNull);
    });

    test("I went between two Didn't go resets the count", () async {
      notifier.enabled = true;
      final service = await started();
      notifier.onTap!(
        const NotificationTap(
          payload: 'a',
          actionId: VisitReminderActions.didntGo,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      notifier.onTap!(const NotificationTap(payload: 'a'));
      await Future<void>.delayed(Duration.zero);
      notifier.onTap!(
        const NotificationTap(
          payload: 'a',
          actionId: VisitReminderActions.didntGo,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect((await tap(service, 'a')).trip, isNotNull);
    });
  });
}
