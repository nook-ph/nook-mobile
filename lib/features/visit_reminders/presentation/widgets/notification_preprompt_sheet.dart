import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/notification_events.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/features/visit_reminders/presentation/visit_reminder_service.dart';
import 'package:nook/injection_container.dart';

/// The in-app ask before the system notification dialog, shown right after
/// a moment that explains it: Directions to a cafe, or a save. Its words
/// only promise what the one channel does today, a reminder to rate a visit.
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

  static const turnOnLabel = 'Turn on';
  static const notNowLabel = 'Not now';

  static String directionsTitle(String cafeName) {
    final name = cafeName.trim();
    return name.isEmpty
        ? 'Want a reminder to rate this cafe after your visit?'
        : 'Want a reminder to rate $name after your visit?';
  }

  static const directionsReason =
      "We'll send one notification in about 90 minutes, so you can rate it "
      'while it is fresh.';

  static const saveTitle = 'Want a reminder to rate cafes you visit?';
  static const saveReason =
      'When you get directions to a cafe, Nook sends one notification '
      'afterwards so you can rate it. Turn it off any time in Settings.';

  /// Shows the sheet; true when "Turn on" was tapped.
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
              style: ProfileTokens.text(14, color: ProfileTokens.muted),
            ),
            const SizedBox(height: 28),
            ProfilePillButton(
              label: turnOnLabel,
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
                    notNowLabel,
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

/// When to show [NotificationPrePromptSheet], and what follows it.
abstract final class VisitReminderPrompts {
  static VisitReminderService? get _service =>
      sl.isRegistered<VisitReminderService>()
      ? sl<VisitReminderService>()
      : null;

  /// Back on the cafe page after Directions to [cafeId]. True when the ask
  /// was shown (the caller then skips its own nudge, one ask at a time).
  static Future<bool> afterDirections(
    BuildContext context,
    String cafeId,
  ) async {
    final service = _service;
    if (service == null) return false;
    final name = await service.takeDirectionsPrompt(cafeId);
    if (name == null || !context.mounted) return false;
    unawaited(
      _ask(
        context,
        service,
        trigger: NotificationPromptTrigger.directions,
        title: NotificationPrePromptSheet.directionsTitle(name),
        reason: NotificationPrePromptSheet.directionsReason,
      ),
    );
    return true;
  }

  /// Just after a Want to try save, once its confirmation has been seen.
  static Future<void> afterSave(BuildContext context) async {
    final service = _service;
    if (service == null) return;
    if (!await service.canShowPrePrompt()) return;
    // Long enough to read "Saved for your next coffee run".
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!context.mounted) return;
    // Left the page, or something else is on top: not now.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    await _ask(
      context,
      service,
      trigger: NotificationPromptTrigger.save,
      title: NotificationPrePromptSheet.saveTitle,
      reason: NotificationPrePromptSheet.saveReason,
    );
  }

  static Future<void> _ask(
    BuildContext context,
    VisitReminderService service, {
    required String trigger,
    required String title,
    required String reason,
  }) async {
    final statuses = context.read<CafeStatusCubit?>();
    final number = await service.recordPrePromptShown();
    final props = {'trigger': trigger};
    logAppEvent(
      NotificationEvents.prePromptShown,
      properties: {...props, 'prompt_number': number},
    );
    if (!context.mounted) return;
    dismissToasts();
    final accepted = await NotificationPrePromptSheet.show(
      context,
      title: title,
      reason: reason,
    );
    if (!accepted) {
      logAppEvent(NotificationEvents.prePromptDismissed, properties: props);
      return;
    }
    logAppEvent(NotificationEvents.prePromptAccepted, properties: props);
    await service.requestPermission(
      trigger: trigger,
      statusOf: statuses?.state.statusFor,
    );
  }
}
