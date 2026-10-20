import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home_widget/data/visit_reminder_decline.dart';
import 'package:nook/features/home_widget/domain/notification_decline.dart';
import 'package:nook/features/visit_reminders/data/local_notifier.dart';
import 'package:nook/features/visit_reminders/data/visit_reminder_store.dart';
import 'package:nook/features/visit_reminders/presentation/visit_reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Notifier implements LocalNotifier {
  bool enabled = false;
  bool muted = false;

  @override
  Future<bool> areEnabled() async => enabled;
  @override
  Future<bool> channelMuted() async => muted;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Notifier notifier;
  late VisitReminderStore store;
  late VisitReminderDecline source;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    notifier = _Notifier();
    store = VisitReminderStore();
    source = VisitReminderDecline(
      VisitReminderService(notifier: notifier, store: store, isIOS: false),
    );
  });

  test('never asked, off (Android 13+ start): unknown', () async {
    expect(await source.decline(), isNull);
  });

  test('"Don\'t allow" after the app\'s ask: denied', () async {
    await store.recordSystemAsk(granted: false, instant: false);
    expect(await source.decline(), NotificationDecline.deniedAfterAsk);
  });

  test('came back at once (refused before): denied', () async {
    await store.recordSystemAsk(granted: false, instant: true);
    expect(await source.decline(), NotificationDecline.deniedAfterAsk);
  });

  test('allowed, then off in Settings: turned off', () async {
    await store.recordSystemAsk(granted: true, instant: false);
    expect(await source.decline(), NotificationDecline.turnedOff);
  });

  test('on: no decline; on with the channel muted: muted', () async {
    notifier.enabled = true;
    expect(await source.decline(), isNull);
    notifier.muted = true;
    expect(await source.decline(), NotificationDecline.channelMuted);
  });

  test('allowed later in Settings wins over an old denial', () async {
    await store.recordSystemAsk(granted: false, instant: false);
    notifier.enabled = true;
    expect(await source.decline(), isNull);
  });
}
