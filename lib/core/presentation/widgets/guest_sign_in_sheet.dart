import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/auth/presentation/sheet_sign_in.dart';
import 'package:nook/features/auth/presentation/widgets/sign_in_choices.dart';

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
  });

  /// Drawn at 24 in brand green inside the 56 tinted circle.
  final IconData icon;

  /// What signing in unlocks, e.g. "Sign in to save cafes".
  final String title;

  /// One or two lines under the title saying what the account is for.
  final String reason;

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
  }) async {
    final props = <String, Object>{'trigger': trigger};
    logAppEvent(SignInPromptEvents.shown, properties: props);
    final choice = await showModalBottomSheet<SignInChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheet,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          GuestSignInSheet(icon: icon, title: title, reason: reason),
    );
    if (choice == null) {
      logAppEvent(SignInPromptEvents.dismissed, properties: props);
      return null;
    }
    if (context.mounted) await continueSignInFromSheet(context, choice);
    return choice;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // The frame is one column with an 8 gap; the two 12-high spacer frames
    // open it up to 28 around the icon/text block.
    const gap = SizedBox(height: 8);

    return Padding(
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
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
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
