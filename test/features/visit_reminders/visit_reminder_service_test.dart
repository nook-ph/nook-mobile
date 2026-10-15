import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/notification_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_statuses_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/set_cafe_status_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/features/visit_reminders/data/local_notifier.dart';
import 'package:nook/features/visit_reminders/data/visit_reminder_store.dart';
import 'package:nook/features/visit_reminders/domain/visit_reminder_rules.dart';
import 'package:nook/features/visit_reminders/presentation/visit_reminder_service.dart';
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

  @override
  Future<bool> areEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    requests++;
    // Long enough to count as a dialog that was on screen.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    enabled = grant;
    return grant;
  }

  @override
  Future<void> openSettings() async {}

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
    SharedPreferences.setMockInitialValues({});
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

  Future<void> directions(VisitReminderService s, String id) =>
      s.onDirections(cafeId: id, cafeName: 'Cafe $id', status: CafeStatus.none);

  test(
    'with permission, Directions schedules "How was …?" 90 min on',
    () async {
      notifier.enabled = true;
      final service = await started();
      await directions(service, 'a');

      final sent = notifier.scheduled[visitReminderIdFor('a')]!;
      expect(sent.at, DateTime(2026, 10, 16, 13, 30));
      expect(sent.title, 'How was Cafe a?');
      expect(sent.payload, 'a');
      expect(analytics.propertiesOf(NotificationEvents.postVisitScheduled), {
        'cafe_id': 'a',
        'delay_min': 90,
        'deferred': false,
        'replaced': 0,
      });
    },
  );

  test('without permission nothing is scheduled', () async {
    final service = await started();
    await directions(service, 'a');
    expect(notifier.scheduled, isEmpty);
    expect(
      analytics.propertiesOf(NotificationEvents.postVisitSkipped)?['reason'],
      'no_permission',
    );
  });

  test(
    'turned off in Settings: nothing scheduled, pending cancelled',
    () async {
      notifier.enabled = true;
      final service = await started();
      await directions(service, 'a');
      await service.setEnabled(false);
      expect(notifier.scheduled, isEmpty);
      await directions(service, 'b');
      expect(notifier.scheduled, isEmpty);
      expect(
        analytics.propertiesOf(NotificationEvents.postVisitSkipped)?['reason'],
        'disabled',
      );
    },
  );

  test('re-tapping Directions reschedules instead of stacking', () async {
    notifier.enabled = true;
    final service = await started();
    await directions(service, 'a');
    clock = clock.add(const Duration(minutes: 20));
    await directions(service, 'a');
    expect(notifier.scheduled.length, 1);
    expect(notifier.scheduled.values.single.at, DateTime(2026, 10, 16, 13, 50));
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

  test('once one went out today, no second today', () async {
    notifier.enabled = true;
    final service = await started();
    await directions(service, 'a');
    clock = DateTime(2026, 10, 16, 15); // a's 13:30 reminder has gone out
    notifier.scheduled.clear();
    await directions(service, 'b');
    expect(notifier.scheduled, isEmpty);
    expect(
      analytics.propertiesOf(NotificationEvents.postVisitSkipped)?['reason'],
      'daily_cap',
    );
  });

  test('a late tap is deferred to 10:00 the next day', () async {
    notifier.enabled = true;
    clock = DateTime(2026, 10, 16, 20, 30);
    final service = await started();
    await directions(service, 'a');
    expect(notifier.scheduled.values.single.at, DateTime(2026, 10, 17, 10));
    expect(
      analytics.propertiesOf(
        NotificationEvents.postVisitScheduled,
      )?['deferred'],
      true,
    );
  });

  test('a cafe already Been gets no reminder', () async {
    notifier.enabled = true;
    final service = await started();
    await service.onDirections(
      cafeId: 'a',
      cafeName: 'A',
      status: CafeStatus.been,
    );
    expect(notifier.scheduled, isEmpty);
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

  group('the in-app ask', () {
    test('after Directions: offered once per trip, while fresh', () async {
      final service = await started();
      await directions(service, 'a');
      expect(await service.takeDirectionsPrompt('b'), isNull);
      expect(await service.takeDirectionsPrompt('a'), 'Cafe a');
      expect(await service.takeDirectionsPrompt('a'), isNull);

      await directions(service, 'a');
      clock = clock.add(const Duration(minutes: 61));
      expect(await service.takeDirectionsPrompt('a'), isNull);
    });

    test('capped at 3, 7 days apart', () async {
      final service = await started();
      for (var i = 0; i < 3; i++) {
        expect(await service.canShowPrePrompt(), isTrue);
        await service.recordPrePromptShown();
        expect(await service.canShowPrePrompt(), isFalse);
        clock = clock.add(const Duration(days: 7));
      }
      expect(await service.canShowPrePrompt(), isFalse);
    });

    test('never once granted', () async {
      notifier.enabled = true;
      final service = await started();
      expect(await service.canShowPrePrompt(), isFalse);
    });

    test('Turn on after Directions schedules from the tap time', () async {
      final service = await started();
      await directions(service, 'a');
      clock = clock.add(const Duration(minutes: 2));
      final granted = await service.requestPermission(
        trigger: NotificationPromptTrigger.directions,
      );
      expect(granted, isTrue);
      expect(
        notifier.scheduled.values.single.at,
        DateTime(2026, 10, 16, 13, 30),
      );
      expect(analytics.propertiesOf(NotificationEvents.permissionResult), {
        'trigger': 'directions',
        'granted': true,
        'prompted': true,
      });
    });

    test('two refusals on Android block further asks', () async {
      notifier.grant = false;
      final service = await started();
      await service.requestPermission(trigger: 'save');
      expect(await service.permission(), NotificationPermission.notAsked);
      await service.requestPermission(trigger: 'save');
      expect(await service.permission(), NotificationPermission.blocked);
      expect(await service.canShowPrePrompt(), isFalse);
    });
  });

  group('taps on the notification', () {
    test('the body opens the cafe; Rate it opens it to rate', () async {
      final service = await started();
      notifier.onTap!(const NotificationTap(payload: 'a'));
      expect(service.openRequests.value?.cafeId, 'a');
      expect(service.openRequests.value?.rate, isFalse);
      notifier.onTap!(
        const NotificationTap(
          payload: 'a',
          actionId: VisitReminderActions.rate,
        ),
      );
      expect(service.openRequests.value?.rate, isTrue);
      expect(analytics.propertiesOf(NotificationEvents.postVisitOpened), {
        'cafe_id': 'a',
        'action': 'rate',
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
      expect(service.openRequests.value, isNull);
      expect(analytics.names, contains(NotificationEvents.postVisitDidntGo));
    });

    test('a cold start from the notification is kept for the router', () async {
      notifier.launch = const NotificationTap(payload: 'a');
      final service = await started();
      expect(service.openRequests.value?.cafeId, 'a');
    });

    test("a background Didn't go is sent on the next start", () async {
      await VisitReminderStore.queueEvent({
        'event': 'didnt_go',
        'cafe_id': 'a',
      });
      await started();
      expect(analytics.propertiesOf(NotificationEvents.postVisitDidntGo), {
        'cafe_id': 'a',
      });
    });
  });
}
