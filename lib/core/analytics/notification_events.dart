// PostHog events for notifications: the in-app ask before the system
// permission dialog, the dialog's answer, the post-visit reminder and the
// Settings switch. Sent through `logAppEvent`. snake_case, object_verb in
// the past tense, like the rest of the app's events. No free text in
// properties (cafe names stay out).

/// The ask, the permission and the visit reminder.
abstract final class NotificationEvents {
  /// The in-app ask ("Want a reminder to rate …?") was shown. Properties:
  /// `trigger` ([NotificationPromptTrigger]), `prompt_number` (1-3).
  static const prePromptShown = 'notification_preprompt_shown';

  /// Its "Turn on" was tapped. Properties: `trigger`.
  static const prePromptAccepted = 'notification_preprompt_accepted';

  /// "Not now", a swipe down or a tap outside. Properties: `trigger`.
  static const prePromptDismissed = 'notification_preprompt_dismissed';

  /// The system dialog's answer. Properties: `trigger` (a
  /// [NotificationPromptTrigger] or `settings`), `granted` (bool),
  /// `prompted` (false when the OS answered without showing a dialog).
  static const permissionResult = 'notification_permission_result';

  /// A reminder to rate a cafe was scheduled after a Directions tap.
  /// Properties: `cafe_id`, `delay_min` (minutes from the tap to delivery),
  /// `deferred` (bool: moved into the 09:00-21:00 window),
  /// `replaced` (how many pending reminders it replaced).
  static const postVisitScheduled = 'post_visit_reminder_scheduled';

  /// A Directions tap that scheduled nothing. Properties: `cafe_id`,
  /// `reason` (`outside_window`, `daily_cap`, `already_been`, `disabled`,
  /// `no_permission`).
  static const postVisitSkipped = 'post_visit_reminder_skipped';

  /// A pending reminder was cancelled before it went out. Properties:
  /// `cafe_id`, `reason` (`marked_been`, `turned_off`).
  static const postVisitCancelled = 'post_visit_reminder_cancelled';

  /// The delivered reminder was tapped and opened the app. Properties:
  /// `cafe_id`, `action` (`open` for the notification itself, `rate` for
  /// "Rate it").
  static const postVisitOpened = 'post_visit_reminder_opened';

  /// "Didn't go" on the reminder. Properties: `cafe_id`.
  static const postVisitDidntGo = 'post_visit_reminder_didnt_go';

  /// The Settings "Visit reminders" switch. Properties: `enabled` (bool),
  /// `permission` (`granted`, `not_asked`, `blocked`) before the change.
  static const visitRemindersToggled = 'visit_reminders_toggled';

  /// Settings' "Open settings" for notifications blocked in the OS.
  static const notificationSettingsOpened = 'notification_settings_opened';
}

/// Values of the `trigger` property.
abstract final class NotificationPromptTrigger {
  static const directions = 'directions';
  static const save = 'save';
  static const settings = 'settings';
}
