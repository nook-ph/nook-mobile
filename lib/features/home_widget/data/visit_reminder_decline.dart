import 'package:nook/features/home_widget/domain/notification_decline.dart';
import 'package:nook/features/visit_reminders/presentation/visit_reminder_service.dart';

/// The widget promo's [NotificationDeclineSource], from the visit-reminder
/// service's record of its own asks.
///
/// - Notifications on, the reminders channel muted:
///   [NotificationDecline.channelMuted].
/// - Off, the system dialog asked for and never granted ("Don't allow", or
///   it came back at once): [NotificationDecline.deniedAfterAsk].
/// - Off, granted before: [NotificationDecline.turnedOff].
/// - Off and never asked (an Android 13+ phone that has not seen the
///   dialog), or on: null. The pre-prompt's "Just directions" never reaches
///   the system dialog, so it is not a decline.
class VisitReminderDecline implements NotificationDeclineSource {
  const VisitReminderDecline(this._reminders);

  final VisitReminderService _reminders;

  @override
  Future<NotificationDecline?> decline() async {
    final a = await _reminders.notificationAnswers();
    if (a.appEnabled) {
      return a.channelMuted ? NotificationDecline.channelMuted : null;
    }
    if (a.everGranted) return NotificationDecline.turnedOff;
    if (a.systemAsks > 0) return NotificationDecline.deniedAfterAsk;
    return null;
  }
}
