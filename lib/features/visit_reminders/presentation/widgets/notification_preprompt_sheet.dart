import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/presentation/session_ask_budget.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/notification_events.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/features/visit_reminders/domain/visit_reminder_rules.dart';
import 'package:nook/features/visit_reminders/presentation/visit_reminder_service.dart';

/// The in-app ask before the system notification dialog, shown at the
/// Directions tap before Maps opens. The title is the real send time, worked
/// out from this tap; "Just directions" goes on to Maps as before.
///
/// Structure follows the guest sign-in sheet (grabber, icon in a tinted
/// circle, centred title and reason) with the two choices stacked under it;
/// see `docs/references/notification-preprompt/README.md`.
class NotificationPrePromptSheet extends StatelessWidget {
  const NotificationPrePromptSheet({
    super.key,
    required this.title,
    required this.reason,
  });

  final String title;
  final String reason;

  static const remindLabel = 'Remind me';
  static const justDirectionsLabel = 'Just directions';

  /// "Want a reminder around 4:35 PM?" or "…tomorrow at 10 AM?".
  static String titleFor(DateTime fireAt, DateTime now) =>
      'Want a reminder ${reminderTimePhrase(fireAt, now)}?';

  static String reasonFor(String cafeName) {
    final name = cafeName.trim().isEmpty ? 'the cafe' : cafeName.trim();
    return 'One notification after your visit to $name, so you can mark it '
        'Been.';
  }

  /// Shows the sheet; true when "Remind me" was tapped.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String reason,
  }) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ProfileTokens.surface,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NotificationPrePromptSheet(title: title, reason: reason),
    );
    return accepted ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    const gap = SizedBox(height: 8);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, math.max(34.0, bottomInset)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ProfileTokens.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: ProfileTokens.tint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.bellRing,
                  size: 24,
                  color: ProfileTokens.brand,
                ),
              ),
            ),
            gap,
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: ProfileTokens.text(20, weight: FontWeight.w600),
              ),
            ),
            gap,
            Text(
              reason,
              textAlign: TextAlign.center,
              // The darker muted (4.6:1): this line carries the promise.
              style: ProfileTokens.text(14, color: ListsTokens.muted),
            ),
            const SizedBox(height: 28),
            ProfilePillButton(
              label: remindLabel,
              onTap: () => Navigator.of(context).pop(true),
            ),
            gap,
            Semantics(
              button: true,
              child: AdaptiveTap(
                onTap: () => Navigator.of(context).pop(false),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  child: Text(
                    justDirectionsLabel,
                    style: ProfileTokens.text(14, weight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "around 4:35 PM", "around 10 AM" (later today), or "tomorrow at 10 AM",
/// in the phone's local time.
String reminderTimePhrase(DateTime fireAt, DateTime now) {
  final minute = fireAt.minute;
  final hour12 = fireAt.hour % 12 == 0 ? 12 : fireAt.hour % 12;
  final period = fireAt.hour >= 12 ? 'PM' : 'AM';
  final time = minute == 0
      ? '$hour12 $period'
      : '$hour12:${minute.toString().padLeft(2, '0')} $period';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(fireAt.year, fireAt.month, fireAt.day);
  return day.difference(today).inDays >= 1
      ? 'tomorrow at $time'
      : 'around $time';
}

/// The ask at a Directions tap, and the line after the system dialog.
abstract final class VisitReminderPrompts {
  static const deniedMessage =
      "Notifications stay off. You can allow them in your phone's settings.";

  static String setMessage(DateTime fireAt, DateTime now) =>
      'Reminder set for ${reminderTimePhrase(fireAt, now)}';

  /// Long enough to read the line before Maps covers it.
  static const readDelay = Duration(milliseconds: 1200);

  /// Shows the ask for [decision] (when it has one) before Maps opens.
  /// Returns once the person has chosen and any system dialog is answered;
  /// the caller then opens Maps either way.
  static Future<void> atDirections(
    BuildContext context,
    VisitReminderService service,
    DirectionsDecision decision, {
    double bottomOffset = 0,
    DateTime Function() now = DateTime.now,
  }) async {
    final trip = decision.trip;
    if (!decision.ask || trip == null) return;
    // One pushed sheet per session, shared with the sign-up ask (ux
    // finding 2). Without the ask there is no permission, so no reminder.
    final budget = SessionAskBudget.instance;
    if (!context.mounted) {
      // The page went away: no ask, so no reminder either.
      await service.dropTrip();
      return;
    }
    if (!budget.canShowSheet) {
      // Without the ask there is no permission, so no reminder: say so,
      // or this Directions tap leaves no trace in the reminder funnel.
      logAppEvent(
        NotificationEvents.prePromptSkipped,
        properties: {
          'cafe_id': trip.cafeId,
          'reason': PrePromptSkipReason.sessionBudget.wire,
        },
      );
      logAppEvent(
        NotificationEvents.postVisitSkipped,
        properties: {
          'cafe_id': trip.cafeId,
          'reason': ReminderSkipReason.noPermission.wire,
        },
      );
      await service.dropTrip();
      return;
    }
    const props = {'trigger': NotificationPromptTrigger.directions};
    final number = await service.prePromptsShownCount() + 1;
    if (!context.mounted || !budget.canShowSheet) {
      // Gone before it could show: nothing was asked, so nothing is spent
      // or counted (the session's sheet, the lifetime asks).
      await service.dropTrip();
      return;
    }
    // From here to the sheet nothing waits, so what is counted is shown.
    budget.spend(SessionAskKind.notificationPrePrompt);
    unawaited(service.recordPrePromptShown());
    logAppEvent(
      NotificationEvents.prePromptShown,
      properties: {...props, 'prompt_number': number},
    );
    dismissToasts();
    final accepted = await NotificationPrePromptSheet.show(
      context,
      title: NotificationPrePromptSheet.titleFor(trip.fireAt, now()),
      reason: NotificationPrePromptSheet.reasonFor(trip.cafeName),
    );
    if (!accepted) {
      logAppEvent(NotificationEvents.prePromptDismissed, properties: props);
      await service.dropTrip();
      return;
    }
    logAppEvent(NotificationEvents.prePromptAccepted, properties: props);
    final granted = await service.requestPermission(
      trigger: NotificationPromptTrigger.directions,
    );
    if (!context.mounted) return;
    showPrimaryToast(
      context,
      granted ? setMessage(trip.fireAt, now()) : deniedMessage,
      bottomOffset: bottomOffset,
    );
    await Future<void>.delayed(readDelay);
  }
}
