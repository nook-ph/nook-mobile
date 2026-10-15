import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/profile/presentation/pages/settings_page.dart';
import 'package:nook/features/visit_reminders/data/local_notifier.dart';
import 'package:nook/features/visit_reminders/data/visit_reminder_store.dart';
import 'package:nook/features/visit_reminders/presentation/visit_reminder_service.dart';
import 'package:nook/features/visit_reminders/presentation/widgets/notification_preprompt_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analytics/recording_analytics.dart';
import 'profile_test_support.dart';

class _Notifier implements LocalNotifier {
  _Notifier({this.enabled = false});

  bool enabled;
  bool grant = true;
  bool muted = false;
  int requests = 0;
  int settingsOpened = 0;
  bool? openedChannel;

  @override
  Future<void> init({required void Function(NotificationTap) onTap}) async {}
  @override
  Future<NotificationTap?> launchTap() async => null;
  @override
  Future<bool> areEnabled() async => enabled;
  @override
  Future<bool> channelMuted() async => muted;
  @override
  Future<bool> requestPermission() async {
    requests++;
    enabled = grant;
    return grant;
  }

  @override
  Future<void> openSettings({bool channel = false}) async {
    settingsOpened++;
    openedChannel = channel;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async {}
  @override
  Future<void> cancel(int id) async {}
}

void main() {
  late RecordingAnalytics analytics;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    analytics = RecordingAnalytics.install(addTearDown);
  });

  Future<VisitReminderService> pump(
    WidgetTester tester,
    _Notifier notifier, {
    bool signedIn = true,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = VisitReminderService(
      notifier: notifier,
      store: VisitReminderStore(),
      isIOS: false,
    );
    await tester.pumpWidget(
      profileHost(
        page: SettingsPage(
          currentUser: () => signedIn ? userWith('email') : null,
          readLocationStatus: () async => SettingsLocationStatus.on,
          reminders: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  Switch reminderSwitch(WidgetTester tester) => tester.widget<Switch>(
    find.descendant(
      of: find.ancestor(
        of: find.text(SettingsPage.visitRemindersLabel),
        matching: find.byType(MergeSemantics),
      ),
      matching: find.byType(Switch),
    ),
  );

  testWidgets('granted: on, and turning it off is saved', (tester) async {
    final service = await pump(tester, _Notifier(enabled: true));
    expect(find.text(SettingsPage.visitRemindersDetail), findsOneWidget);
    expect(reminderSwitch(tester).value, isTrue);

    await tester.tap(find.text(SettingsPage.visitRemindersLabel));
    await tester.pumpAndSettle();
    expect(reminderSwitch(tester).value, isFalse);
    expect(await service.remindersEnabled(), isFalse);
    expect(analytics.propertiesOf('visit_reminders_toggled'), {
      'enabled': false,
      'permission': 'granted',
    });
  });

  testWidgets('not asked yet: off, and turning it on asks the system', (
    tester,
  ) async {
    final notifier = _Notifier();
    await pump(tester, notifier);
    expect(reminderSwitch(tester).value, isFalse);

    await tester.tap(find.text(SettingsPage.visitRemindersLabel));
    await tester.pumpAndSettle();
    expect(notifier.requests, 1);
    expect(reminderSwitch(tester).value, isTrue);
  });

  testWidgets('blocked: says so and opens the phone settings', (tester) async {
    final notifier = _Notifier();
    SharedPreferences.setMockInitialValues({'visitReminders.systemAsks': 2});
    await pump(tester, notifier);

    expect(find.text(SettingsPage.visitRemindersBlocked), findsOneWidget);
    expect(find.text(SettingsPage.openSettingsLabel), findsOneWidget);
    expect(reminderSwitch(tester).onChanged, isNull);

    await tester.tap(find.text(SettingsPage.openSettingsLabel));
    await tester.pumpAndSettle();
    expect(notifier.settingsOpened, 1);
    expect(notifier.openedChannel, isFalse);
    expect(notifier.requests, 0);
  });

  testWidgets('a muted reminders channel shows as blocked', (tester) async {
    final notifier = _Notifier(enabled: true)..muted = true;
    await pump(tester, notifier);

    expect(find.text(SettingsPage.visitRemindersMuted), findsOneWidget);
    expect(reminderSwitch(tester).value, isFalse);
    expect(reminderSwitch(tester).onChanged, isNull);

    await tester.tap(find.text(SettingsPage.openSettingsLabel));
    await tester.pumpAndSettle();
    expect(notifier.openedChannel, isTrue);
  });

  testWidgets('a refusal says notifications stay off', (tester) async {
    final notifier = _Notifier()..grant = false;
    await pump(tester, notifier);

    await tester.tap(find.text(SettingsPage.visitRemindersLabel));
    await tester.pumpAndSettle();
    expect(find.text(VisitReminderPrompts.deniedMessage), findsOneWidget);
    expect(reminderSwitch(tester).value, isFalse);
    await letToastExpire(tester);
  });

  testWidgets('visit reminders sit under Notifications', (tester) async {
    await pump(tester, _Notifier(enabled: true));
    final group = tester.getTopLeft(find.text(SettingsPage.notificationsGroup));
    final row = tester.getTopLeft(find.text(SettingsPage.visitRemindersLabel));
    final location = tester.getTopLeft(find.text('Location'));
    expect(group.dy, greaterThan(location.dy));
    expect(row.dy, greaterThan(group.dy));
  });

  testWidgets('a guest sees Permissions, Notifications and Legal only', (
    tester,
  ) async {
    await pump(tester, _Notifier(enabled: true), signedIn: false);
    expect(find.text(SettingsPage.visitRemindersLabel), findsOneWidget);
    expect(find.text('Legal'), findsOneWidget);
    for (final hidden in ['Privacy', 'Account', 'Log out', 'Delete account']) {
      expect(find.text(hidden), findsNothing);
    }
  });
}
