import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nook/features/cafe_details/presentation/guest_action_replay.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/auth/presentation/sheet_sign_in.dart';
import 'package:nook/features/auth/presentation/widgets/sign_in_choices.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';

/// Which guest action opened the sign-in sheet; each gets its own reason.
enum CafeGuestAction {
  been,
  wantToTry,
  saveToList,
  writeReview,
  reportReview,
  helpfulReview,
}

/// Says why an account is needed before a guest's Been, Want to try, Save,
/// or a review action (write, report, helpful), instead of dropping them on
/// the login page. Google and Apple sign in from the sheet; email opens the
/// login page. "Not now" leaves them where they were.
class CafeGuestSignInSheet extends StatelessWidget {
  const CafeGuestSignInSheet({
    super.key,
    required this.action,
    required this.cafeName,
    this.title,
    this.reason,
  });

  final CafeGuestAction action;
  final String cafeName;

  /// Replaces the action's own title ([titleFor]) when the caller has a
  /// better one for where the guest is.
  final String? title;

  /// Replaces the action's own reason ([messageFor]), e.g. "Keep your saves
  /// on any phone".
  final String? reason;

  static const _sheetColor = Color(0xFFFEFEFE);
  static const _grabber = Color(0xFFE0E0E0);
  static const _muted = Color(0xFF868584);

  /// Opens the sheet. Google or Apple signs in from here; email pushes
  /// `/login` ([continueSignInFromSheet]). With [cafeId], a Save, Been,
  /// Want to try or Write a review is finished on that cafe's page once the
  /// guest is signed in ([GuestActionReplay]). [title] and [reason] replace
  /// the action's own copy.
  static Future<void> show(
    BuildContext context, {
    required CafeGuestAction action,
    String cafeName = '',
    String? cafeId,
    String? title,
    String? reason,
  }) async {
    final choice = await showModalBottomSheet<SignInChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetColor,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CafeGuestSignInSheet(
        action: action,
        cafeName: cafeName,
        title: title,
        reason: reason,
      ),
    );
    if (!context.mounted) return;
    await continueSignInFromSheet(
      context,
      choice,
      beforeSignIn: () {
        if (cafeId != null) GuestActionReplay.remember(action, cafeId);
      },
    );
  }

  static String titleFor(CafeGuestAction action, String cafeName) {
    final name = cafeName.trim();
    return switch (action) {
      CafeGuestAction.been => 'Sign in to keep a Been list',
      CafeGuestAction.wantToTry =>
        name.isEmpty ? 'Sign in to save this cafe' : 'Sign in to save $name',
      CafeGuestAction.saveToList => 'Sign in to save to a list',
      CafeGuestAction.writeReview => 'Sign in to add your cup',
      CafeGuestAction.reportReview => 'Sign in to report a cup',
      CafeGuestAction.helpfulReview => 'Sign in to mark cups helpful',
    };
  }

  static String messageFor(CafeGuestAction action) => switch (action) {
    CafeGuestAction.been =>
      'Mark cafes you have visited, rank them and add notes.',
    CafeGuestAction.wantToTry =>
      'Keep a Want to try list and come back to it later.',
    CafeGuestAction.saveToList => 'Make your own lists and add cafes to them.',
    CafeGuestAction.writeReview =>
      'Cups are posted under your name. Signing in takes a minute.',
    // Not drawn in Figma (only Write and Helpful are); same voice.
    CafeGuestAction.reportReview =>
      'Reports are tied to your account so our team can follow up.',
    CafeGuestAction.helpfulReview =>
      'Helpful votes are tied to your account so each person counts once.',
  };

  static IconData iconFor(CafeGuestAction action) => switch (action) {
    CafeGuestAction.been ||
    CafeGuestAction.wantToTry ||
    CafeGuestAction.saveToList => LucideIcons.bookmark,
    CafeGuestAction.writeReview => LucideIcons.penLine,
    CafeGuestAction.reportReview => LucideIcons.flag,
    CafeGuestAction.helpfulReview => LucideIcons.thumbsUp,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
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
              color: CafeDetailsTokens.tint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconFor(action),
              size: 24,
              color: CafeDetailsTokens.brand,
            ),
          ),
          gap,
          Text(
            title ?? titleFor(action, cafeName),
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CafeDetailsTokens.ink,
            ),
          ),
          gap,
          Text(
            reason ?? messageFor(action),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(fontSize: 14, color: _muted),
          ),
          gap,
          const SizedBox(height: 12),
          gap,
          SheetSignInChoices(
            onChoice: (choice) => Navigator.of(context).pop(choice),
          ),
          gap,
          _SheetButton(
            label: 'Not now',
            height: 44,
            textColor: CafeDetailsTokens.ink,
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
          constraints: BoxConstraints(minHeight: height),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
