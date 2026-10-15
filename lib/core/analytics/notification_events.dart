// PostHog events for notifications: the in-app ask before the system
// permission dialog, the dialog's answer, the post-visit reminder and the
// Settings switch. Sent through `logAppEvent`. snake_case, object_verb in
// the past tense, like the rest of the app's events. No free text in
// properties (cafe names stay out).

/// The ask, the permission and the visit reminder.
abstract final class NotificationEvents {
  /// The in-app ask at a Directions tap ("Want a reminder around 4:35
  /// PM?") was shown. Properties: `trigger` ([NotificationPromptTrigger]),
  /// `prompt_number` (1-3).
  static const prePromptShown = 'notification_preprompt_shown';

  /// A Directions tap that showed no ask. Properties: `cafe_id`, `reason`:
  /// nothing would be sent (`closed`, `outside_window`, `daily_cap`,
  /// `paused`, `already_been`, `disabled`), or no ask was due (`granted`,
  /// `blocked`, `holdout`, `cap`, `gap`).
  static const prePromptSkipped = 'notification_preprompt_skipped';

  /// Its "Remind me" was tapped. Properties: `trigger`.
  static const prePromptAccepted = 'notification_preprompt_accepted';

  /// "Just directions", a swipe down or a tap outside. Properties: `trigger`.
  static const prePromptDismissed = 'notification_preprompt_dismissed';

  /// The system dialog's answer. Properties: `trigger` (a
  /// [NotificationPromptTrigger] or `settings`), `granted` (bool),
  /// `prompted` (false when the OS answered without showing a dialog).
  static const permissionResult = 'notification_permission_result';

  /// "Did you make it to …?" was scheduled after a Directions tap.
  /// Properties: `cafe_id`, `delay_min` (minutes from the tap to delivery),
  /// `deferred` (bool: not exactly 90 min after the tap: moved into the
  /// 09:00-21:00 window or counted from opening), `replaced` (how many
  /// pending reminders it replaced), `cafe_open` (`open`, `opens_later`,
  /// `unknown`), `promised_at` (ISO-8601 UTC, the time the ask showed).
  static const postVisitScheduled = 'post_visit_reminder_scheduled';

  /// A Directions tap that scheduled nothing. Properties: `cafe_id`,
  /// `reason` (`outside_window`, `daily_cap`, `closed`, `paused`,
  /// `already_been`, `disabled`, `no_permission`).
  static const postVisitSkipped = 'post_visit_reminder_skipped';

  /// A pending reminder was cancelled before it went out. Properties:
  /// `cafe_id`, `reason` (`marked_been`, `turned_off`).
  static const postVisitCancelled = 'post_visit_reminder_cancelled';

  /// The delivered reminder was tapped and opened the app; both mean "I
  /// went". Properties: `cafe_id`, `action` (`body` for the notification
  /// itself, `went` for "I went").
  static const postVisitOpened = 'post_visit_reminder_opened';

  /// "Didn't go" on the reminder. Properties: `cafe_id`.
  static const postVisitDidntGo = 'post_visit_reminder_didnt_go';

  /// A second "Didn't go" in a row paused a cafe's reminders. Properties:
  /// `cafe_id`, `days` (30).
  static const postVisitPaused = 'post_visit_reminder_paused';

  /// Once per app open. Properties: `app_enabled` (bool), `channel_muted`
  /// (bool, Android's "Visits and ratings" channel), `permission`
  /// (`granted`, `not_asked`, `blocked`), `reminders_enabled` (bool),
  /// `holdout_arm` (`ask`, `holdout`).
  static const notificationState = 'notification_state';

  /// The first time an install is bucketed. Properties: `arm` (`ask`, or
  /// `holdout` for the 10% that never get the ask).
  static const holdoutAssigned = 'notification_holdout_assigned';

  /// The Settings "Visit reminders" switch. Properties: `enabled` (bool),
  /// `permission` (`granted`, `not_asked`, `blocked`) before the change.
  static const visitRemindersToggled = 'visit_reminders_toggled';

  /// Settings' "Open settings" for notifications blocked in the OS.
  static const notificationSettingsOpened = 'notification_settings_opened';
}

/// Values of the `trigger` property.
abstract final class NotificationPromptTrigger {
  static const directions = 'directions';
  static const settings = 'settings';
}
