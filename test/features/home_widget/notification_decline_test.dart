import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home_widget/domain/notification_decline.dart';
import 'package:nook/features/home_widget/domain/widget_promo_rules.dart';

void main() {
  NotificationsState resolve({
    int? sdk,
    bool? enabled,
    NotificationDecline? decline,
  }) => NotificationsState.resolve(
    sdkInt: sdk,
    enabled: enabled,
    decline: decline,
  );
  const denied = NotificationDecline.deniedAfterAsk;

  group('NotificationsState.resolve', () {
    test('never asked on 33+ is unknown, not off', () {
      final s = resolve(sdk: 35, enabled: false);
      expect(s, NotificationsState.unknown);
      expect(s.off, isNull);
      expect(s.declineKind, isNull);
    });

    test('"Don\'t allow" after the app\'s own ask is a decline', () {
      final s = resolve(sdk: 35, enabled: false, decline: denied);
      expect(s, NotificationsState.systemDenied);
      expect(s.off, isTrue);
      expect(s.declineKind, 'system_denied');
    });

    test('disabled on SDK < 33 is a decline', () {
      final s = resolve(sdk: 32, enabled: false);
      expect(s, NotificationsState.sdkDisabled);
      expect(s.off, isTrue);
      expect(s.declineKind, 'sdk_disabled');
    });

    test('below SDK 33 a recorded ask does not change the kind', () {
      // No dialog exists there: the reminder ask is answered at once.
      for (final d in [denied, NotificationDecline.turnedOff]) {
        final s = resolve(sdk: 32, enabled: false, decline: d);
        expect(s, NotificationsState.sdkDisabled);
        expect(s.declineKind, 'sdk_disabled');
      }
    });

    test('asked and allowed, or on, is on', () {
      expect(resolve(sdk: 35, enabled: true), NotificationsState.on);
      expect(resolve(sdk: 35, enabled: false).off, isNull);
      // Allowed later in Settings wins over an old decline.
      expect(
        resolve(sdk: 35, enabled: true, decline: denied),
        NotificationsState.on,
      );
      expect(resolve(sdk: 30, enabled: true).off, isFalse);
    });

    test('turned off after allowing is a decline', () {
      final s = resolve(
        sdk: 35,
        enabled: false,
        decline: NotificationDecline.turnedOff,
      );
      expect(s, NotificationsState.settingsOff);
      expect(s.off, isTrue);
      expect(s.declineKind, 'settings_off');
    });

    test('on, with the reminders channel muted, is a decline', () {
      final s = resolve(
        sdk: 35,
        enabled: true,
        decline: NotificationDecline.channelMuted,
      );
      expect(s, NotificationsState.channelMuted);
      expect(s.off, isTrue);
      expect(s.declineKind, 'channel_muted');
    });

    test('nothing known is unknown', () {
      expect(resolve(), NotificationsState.unknown);
      expect(resolve(enabled: false), NotificationsState.unknown);
    });

    test('the default source says unknown', () async {
      expect(await const UnknownNotificationDecline().decline(), isNull);
    });
  });

  test('a never-asked 33+ phone with 3 saves gets the saves card', () {
    final reason = WidgetPromoRules.decide(
      history: const WidgetPromoHistory(),
      wantToTryCount: 3,
      notificationsOff: resolve(sdk: 35, enabled: false).off,
      canPin: true,
      installedCount: 0,
      now: DateTime.utc(2026, 10, 16),
    );
    expect(reason, WidgetPromoReason.saves);
  });
}
