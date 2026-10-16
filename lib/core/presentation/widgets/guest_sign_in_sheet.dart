import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/presentation/session_ask_budget.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/auth/presentation/sheet_sign_in.dart';
import 'package:nook/features/auth/presentation/widgets/sign_in_choices.dart';
import 'package:nook/core/preferences/session_prompts.dart';

/// Tells a guest why an action needs an account instead of dropping them on
/// the login page. Google and Apple sign in from the sheet; email opens the
/// login page. "Not now" leaves them where they were.
///
/// [title] and [reason] are the caller's, so each place can say what the
/// account is for there ("Keep your saves on any phone").
///
/// Values are the Figma "Sheet / Guest sign-in" frame (1605:11273, and the
/// Saved / Profile variants 1605:15849 and 1605:16067).
class GuestSignInSheet extends StatelessWidget {
  const GuestSignInSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.reason,
    this.confirmation,
    this.stayLabel,
  });

  /// Drawn at 24 in brand green inside the 56 tinted circle.
  final IconData icon;

  /// What signing in unlocks, e.g. "Sign in to save cafes".
  final String title;

  /// One or two lines under the title saying what the account is for.
  final String reason;

  /// A first line confirming what the person just did ("Flavour Coffee
  /// saved"), with a check, when the sheet opened right after it.
  final String? confirmation;

  /// A third choice under Not now that also declines, worded as a real
  /// choice ("Keep using on this phone").
  final String? stayLabel;

  /// The single button the sheet used to have. No longer shown: Google,
  /// Apple and email ([SheetSignInChoices]) took its place.
  static const primaryLabel = 'Sign in or create account';
  static const dismissLabel = 'Not now';

  static const _sheet = Color(0xFFFEFEFE);
  static const _grabber = Color(0xFFE0E0E0);
  static const _tint = Color(0xFFEEEEEE);
  static const _brand = Color(0xFF344E41);
  static const _ink = Color(0xFF0A0F0D);
  static const _muted = Color(0xFF868584);

  /// Opens the sheet. Google or Apple signs in from here and comes back to
  /// this page; email pushes `/login` ([continueSignInFromSheet]).
  ///
  /// [trigger] names what needed an account (`saved_tab`, `save_place`, ...)
  /// for `signin_prompt_shown` / `signin_prompt_dismissed`.
  ///
  /// Returns how they chose to sign in, or null when the sheet was
  /// dismissed ("Not now", a swipe, Back).
  static Future<SignInChoice?> show(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String reason,
    String trigger = 'other',
  }) async => (await showDetailed(
    context,
    icon: icon,
    title: title,
    reason: reason,
    trigger: trigger,
  )).choice;

  /// [show], also saying how a dismissal happened. [pushed]: the app opened
  /// it (the engagement score's ask) rather than the person; a sheet they
  /// opened themselves stops score asks for the session
  /// ([SessionAskBudget]).
  static Future<GuestSignInOutcome> showDetailed(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String reason,
    String trigger = 'other',
    String? confirmation,
    String? stayLabel,
    bool pushed = false,
  }) async {
    final props = <String, Object>{'trigger': trigger};
    SessionPrompts.noteShown();
    logAppEvent(SignInPromptEvents.shown, properties: props);
    if (!pushed) {
      SessionAskBudget.instance.blockScoreAsks(SessionAskKind.pullSignIn);
    }
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheet,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => GuestSignInSheet(
        icon: icon,
        title: title,
        reason: reason,
        confirmation: confirmation,
        stayLabel: stayLabel,
      ),
    );
    if (result is! SignInChoice) {
      logAppEvent(SignInPromptEvents.dismissed, properties: props);
      return GuestSignInOutcome(
        dismissedBy: result is GuestSheetDismissal
            ? result
            : GuestSheetDismissal.swipeOrBack,
      );
    }
    if (context.mounted) await continueSignInFromSheet(context, result);
    return GuestSignInOutcome(choice: result);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // The frame is one column with an 8 gap; the two 12-high spacer frames
    // open it up to 28 around the icon/text block.
    const gap = SizedBox(height: 8);

    // Scrolls when it outgrows the screen: at 2.0x text the repeat ask,
    // with its third choice, is taller than the phone.
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, math.max(34.0, bottomInset)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _grabber,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            gap,
            if (confirmation case final line?)
              _ConfirmationLine(text: line)
            else
              const SizedBox(height: 12),
            gap,
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: _tint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: _brand),
            ),
            gap,
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            gap,
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _muted,
              ),
            ),
            gap,
            const SizedBox(height: 12),
            gap,
            SheetSignInChoices(
              onChoice: (choice) => Navigator.of(context).pop(choice),
            ),
            gap,
            _SheetButton(
              label: dismissLabel,
              // 48: the touch floor (review finding 6).
              height: 48,
              textColor: _ink,
              onTap: () =>
                  Navigator.of(context).pop(GuestSheetDismissal.notNow),
            ),
            if (stayLabel case final label?)
              _SheetButton(
                label: label,
                height: 48,
                // Ink, like Not now: a real choice, and muted text on the
                // sheet is under 4.5:1.
                textColor: _ink,
                onTap: () =>
                    Navigator.of(context).pop(GuestSheetDismissal.stayOnPhone),
              ),
          ],
        ),
      ),
    );
  }
}

/// How a [GuestSignInSheet] ended.
class GuestSignInOutcome {
  const GuestSignInOutcome({this.choice, this.dismissedBy});

  /// The sign-in chosen, or null when dismissed.
  final SignInChoice? choice;

  /// How it was dismissed, when it was.
  final GuestSheetDismissal? dismissedBy;
}

/// The ways out of the sheet without signing in. [wire] is the `how`
/// property of `signup_ask_dismissed`.
enum GuestSheetDismissal {
  notNow('not_now'),

  /// A swipe down, a tap above the sheet or system Back: the sheet cannot
  /// tell these apart.
  swipeOrBack('swipe_or_back'),
  stayOnPhone('stay_on_phone');

  const GuestSheetDismissal(this.wire);

  final String wire;
}

/// "✓ Flavour Coffee saved": the sheet's first line when it opened right
/// after a save, so the save is confirmed before anything is asked.
class _ConfirmationLine extends StatelessWidget {
  const _ConfirmationLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.circleCheck,
              size: 18,
              color: GuestSignInSheet._brand,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: GuestSignInSheet._brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.height,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final double height;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: double.infinity,
          // A minimum, so the label can grow with large text settings.
          constraints: BoxConstraints(minHeight: height),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
