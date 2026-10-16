/// Whether someone really turned Nook's notifications down, for the
/// "Prefer no notifications?" widget card.
///
/// On Android 13+ (SDK 33) notifications start off until the app asks, so
/// "off" alone mostly means "never asked". Only these count as a decline:
/// - the system "Don't allow" after Nook's own ask
///   ([NotificationDecline.deniedAfterAsk]);
/// - allowed once, then turned off in the phone's settings
///   ([NotificationDecline.turnedOff]);
/// - notifications on, but Nook's visit reminders channel muted
///   ([NotificationDecline.channelMuted]);
/// - notifications disabled on SDK < 33, where they start on, so off is a
///   choice the person made in Settings.
/// Anything else is unknown, and the widget card falls back to its saves
/// reason.
enum NotificationsState {
  /// Nook may post notifications.
  on,

  /// The system dialog was answered "Don't allow" after Nook asked.
  systemDenied,

  /// Allowed once, then turned off in the phone's settings.
  settingsOff,

  /// On for Nook, but the visit reminders channel is muted.
  channelMuted,

  /// Disabled in Settings on SDK < 33.
  sdkDisabled,

  /// Never asked on SDK 33+, or nothing known.
  unknown;

  /// What `WidgetPromoRules.decide` takes as `notificationsOff`: true for a
  /// real decline, false when on, null when unknown.
  bool? get off => switch (this) {
    on => false,
    systemDenied || settingsOff || channelMuted || sdkDisabled => true,
    unknown => null,
  };

  /// `decline_kind` on the promo events, for a decline only.
  String? get declineKind => switch (this) {
    systemDenied => 'system_denied',
    settingsOff => 'settings_off',
    channelMuted => 'channel_muted',
    sdkDisabled => 'sdk_disabled',
    _ => null,
  };

  /// Android 13, where POST_NOTIFICATIONS became a runtime permission.
  static const askSdk = 33;

  /// [enabled] is `areNotificationsEnabled()` (null unknown), [sdkInt] the
  /// phone's API level (null unknown), [decline] from
  /// [NotificationDeclineSource] (null: never asked, asked and allowed, or
  /// not recorded).
  static NotificationsState resolve({
    required int? sdkInt,
    required bool? enabled,
    required NotificationDecline? decline,
  }) {
    // On for the app, yet the reminders it would send are muted.
    if (decline == NotificationDecline.channelMuted && enabled != false) {
      return channelMuted;
    }
    if (enabled == true) return on;
    // Below SDK 33 there is no system dialog: an "ask" there is answered at
    // once by the OS, so a recorded decline says nothing new. Off is a
    // Settings choice.
    if (enabled == false && sdkInt != null && sdkInt < askSdk) {
      return sdkDisabled;
    }
    // Allowed later in Settings reads as on above; otherwise a recorded
    // decline stands.
    if (decline == NotificationDecline.deniedAfterAsk) return systemDenied;
    if (decline == NotificationDecline.turnedOff) return settingsOff;
    return unknown;
  }
}

/// A decline recorded by the app's own notification ask (the visit-reminder
/// pre-prompt at Directions, then the system dialog).
enum NotificationDecline {
  /// The system dialog was asked for and never granted ("Don't allow", or
  /// it came back at once because it was refused before).
  deniedAfterAsk,

  /// Granted once, off now: turned off in the phone's settings.
  turnedOff,

  /// On for Nook, but the visit reminders channel is muted.
  channelMuted,
}

/// Where a recorded answer to Nook's own notification ask comes from.
///
/// The app's source is `VisitReminderDecline` (the visit-reminder
/// service's record of its asks). Do not count the pre-prompt's "Just
/// directions": that is "not now" for one trip, and the system dialog never
/// showed.
abstract class NotificationDeclineSource {
  /// The decline, or null: never asked, asked and allowed, or not known.
  Future<NotificationDecline?> decline();
}

/// Knows nothing: every answer is unknown. For tests and builds without
/// visit reminders.
class UnknownNotificationDecline implements NotificationDeclineSource {
  const UnknownNotificationDecline();

  @override
  Future<NotificationDecline?> decline() async => null;
}
