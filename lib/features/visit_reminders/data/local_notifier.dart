import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nook/features/visit_reminders/data/visit_reminder_store.dart';
import 'package:timezone/timezone.dart' as tz;

/// Nook's notification channels (Android) and what each is for. Only
/// [visits] exists today. Later ones ("Your saved cafes", "New in Cebu",
/// "Nook updates") get their own entry here, so people can mute one kind
/// without muting all of them; a channel is created the first time
/// something is sent on it.
enum NookChannel {
  visits(
    id: 'visits_and_ratings',
    name: 'Visits and ratings',
    description: 'A quick reminder to rate a cafe after you visit',
  );

  const NookChannel({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;
}

/// Ids carried by the post-visit notification and its buttons.
abstract final class VisitReminderActions {
  static const rate = 'rate';
  static const didntGo = 'didnt_go';
  static const category = 'visit_reminder';

  static const rateLabel = 'Rate it';
  static const didntGoLabel = "Didn't go";
}

/// A tap on one of Nook's notifications, reduced to what the app needs.
class NotificationTap {
  const NotificationTap({required this.payload, this.actionId, this.id});

  final String? payload;

  /// Null for a tap on the notification itself.
  final String? actionId;
  final int? id;
}

/// The phone's notification system, as Nook uses it. An interface so the
/// scheduling logic can be tested without the plugin.
abstract class LocalNotifier {
  /// Sets the plugin up without asking for anything. [onTap] gets taps that
  /// open the app.
  Future<void> init({required void Function(NotificationTap tap) onTap});

  /// The tap that launched the app from scratch, if any.
  Future<NotificationTap?> launchTap();

  Future<bool> areEnabled();

  /// Shows the system dialog where the platform has one. True if granted.
  Future<bool> requestPermission();

  Future<void> openSettings();

  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  });

  Future<void> cancel(int id);
}

/// Runs in a background isolate when a button that does not open the app
/// ("Didn't go") is tapped. The notification is already dismissed by the
/// OS ([AndroidNotificationAction.cancelNotification]); this only queues
/// the analytics event for the app to send next time it is open.
@pragma('vm:entry-point')
void visitReminderBackgroundTap(NotificationResponse response) async {
  if (response.actionId != VisitReminderActions.didntGo) return;
  try {
    await VisitReminderStore.queueEvent({
      'event': 'didnt_go',
      'cafe_id': ?response.payload,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {}
}

class PluginLocalNotifier implements LocalNotifier {
  PluginLocalNotifier([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init({required void Function(NotificationTap tap) onTap}) async {
    if (_ready) return;
    final settings = InitializationSettings(
      android: const AndroidInitializationSettings('ic_stat_nook'),
      // Nothing is asked at launch: the in-app ask comes first, after a
      // Directions tap or a save.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: [
          DarwinNotificationCategory(
            VisitReminderActions.category,
            actions: [
              DarwinNotificationAction.plain(
                VisitReminderActions.rate,
                VisitReminderActions.rateLabel,
                options: {DarwinNotificationActionOption.foreground},
              ),
              DarwinNotificationAction.plain(
                VisitReminderActions.didntGo,
                VisitReminderActions.didntGoLabel,
              ),
            ],
          ),
        ],
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) => onTap(
        NotificationTap(
          payload: response.payload,
          actionId: response.actionId,
          id: response.id,
        ),
      ),
      onDidReceiveBackgroundNotificationResponse: visitReminderBackgroundTap,
    );
    _ready = true;
  }

  @override
  Future<NotificationTap?> launchTap() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    if (details?.didNotificationLaunchApp != true || response == null) {
      return null;
    }
    return NotificationTap(
      payload: response.payload,
      actionId: response.actionId,
      id: response.id,
    );
  }

  @override
  Future<bool> areEnabled() async {
    try {
      if (_isIOS) {
        final options = await _ios?.checkPermissions();
        return options?.isEnabled ?? false;
      }
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      if (_isIOS) {
        return await _ios?.requestPermissions(
              alert: true,
              badge: false,
              sound: true,
            ) ??
            false;
      }
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openSettings() async {
    try {
      await _plugin.openAppNotificationSettings();
    } catch (_) {}
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async {
    const channel = NookChannel.visits;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        category: AndroidNotificationCategory.reminder,
        icon: 'ic_stat_nook',
        color: const Color(0xFF344E41),
        autoCancel: true,
        actions: const [
          AndroidNotificationAction(
            VisitReminderActions.rate,
            VisitReminderActions.rateLabel,
            showsUserInterface: true,
          ),
          AndroidNotificationAction(
            VisitReminderActions.didntGo,
            VisitReminderActions.didntGoLabel,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        categoryIdentifier: VisitReminderActions.category,
      ),
    );
    // The rules work in local time; the OS only needs the instant, so it
    // goes over as UTC and no time zone database is needed.
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      notificationDetails: details,
      // Inexact on purpose: a reminder a few minutes late is fine, and it
      // needs no exact-alarm permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }
}
