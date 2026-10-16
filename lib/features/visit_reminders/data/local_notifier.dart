import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    description: 'One reminder to mark a cafe Been after you get directions',
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
  static const went = 'went';
  static const didntGo = 'didnt_go';
  static const category = 'visit_reminder';

  static const wentLabel = 'I went';
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

  /// Whether the OS lets Nook post at all (app level).
  Future<bool> areEnabled();

  /// Whether the visit reminders channel is muted on its own in the
  /// phone's settings (Android). False where channels don't exist.
  Future<bool> channelMuted();

  /// Shows the system dialog where the platform has one. True if granted.
  Future<bool> requestPermission();

  /// The phone's notification settings for Nook; with [channel], the
  /// visit reminders channel's own page where the platform has one.
  Future<void> openSettings({bool channel = false});

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
    // A headless isolate: register the Dart side of plugins
    // (shared_preferences) before using them. Idempotent.
    DartPluginRegistrant.ensureInitialized();
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

  /// `MainActivity`: opens one channel's settings page.
  static const _settings = MethodChannel('app.nookph/notification_settings');

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
                VisitReminderActions.went,
                VisitReminderActions.wentLabel,
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
    // Made up front, so the channel is in the phone's settings (and can be
    // read as muted) before the first reminder. Asks for nothing.
    try {
      await _android?.createNotificationChannel(_visitsChannel);
    } catch (_) {}
    _ready = true;
  }

  static AndroidNotificationChannel get _visitsChannel =>
      AndroidNotificationChannel(
        NookChannel.visits.id,
        NookChannel.visits.name,
        description: NookChannel.visits.description,
      );

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
  Future<bool> channelMuted() async {
    if (_isIOS) return false;
    try {
      final channels = await _android?.getNotificationChannels();
      for (final c in channels ?? const <AndroidNotificationChannel>[]) {
        if (c.id == NookChannel.visits.id) {
          return c.importance == Importance.none;
        }
      }
    } catch (_) {}
    return false;
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
  Future<void> openSettings({bool channel = false}) async {
    if (channel && !_isIOS) {
      try {
        final opened = await _settings.invokeMethod<bool>('openChannel', {
          'channelId': NookChannel.visits.id,
        });
        if (opened == true) return;
      } catch (_) {}
    }
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
            VisitReminderActions.went,
            VisitReminderActions.wentLabel,
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
