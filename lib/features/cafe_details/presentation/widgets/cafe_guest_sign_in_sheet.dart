import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
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
/// the login page. "Not now" leaves them where they were.
class CafeGuestSignInSheet extends StatelessWidget {
  const CafeGuestSignInSheet({
    super.key,
    required this.action,
    required this.cafeName,
  });

  final CafeGuestAction action;
  final String cafeName;

  static const _sheetColor = Color(0xFFFEFEFE);
  static const _grabber = Color(0xFFE0E0E0);
  static const _muted = Color(0xFF868584);

  /// Opens the sheet; "Sign in or create account" pushes `/login`.
  static Future<void> show(
    BuildContext context, {
    required CafeGuestAction action,
    String cafeName = '',
  }) async {
    final signIn = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetColor,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CafeGuestSignInSheet(action: action, cafeName: cafeName),
    );
    if (signIn == true && context.mounted) context.push('/login');
  }

  static String titleFor(CafeGuestAction action, String cafeName) {
    final name = cafeName.trim();
    return switch (action) {
      CafeGuestAction.been => 'Sign in to keep a Been list',
      CafeGuestAction.wantToTry =>
        name.isEmpty ? 'Sign in to save this cafe' : 'Sign in to save $name',
      CafeGuestAction.saveToList => 'Sign in to save to a list',
      CafeGuestAction.writeReview => 'Sign in to write a review',
      CafeGuestAction.reportReview => 'Sign in to report a review',
      CafeGuestAction.helpfulReview => 'Sign in to mark reviews helpful',
    };
  }

  static String messageFor(CafeGuestAction action) => switch (action) {
    CafeGuestAction.been =>
      'Mark cafes you have visited, rank them and add notes.',
    CafeGuestAction.wantToTry =>
      'Keep a Want to try list and come back to it later.',
    CafeGuestAction.saveToList => 'Make your own lists and add cafes to them.',
    CafeGuestAction.writeReview =>
      'Reviews are posted under your name. Signing in takes a minute.',
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
            titleFor(action, cafeName),
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: CafeDetailsTokens.ink,
            ),
          ),
          gap,
          Text(
            messageFor(action),
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(fontSize: 14, color: _muted),
          ),
          gap,
          const SizedBox(height: 12),
          gap,
          _SheetButton(
            label: 'Sign in or create account',
            height: 48,
            color: CafeDetailsTokens.brand,
            textColor: _sheetColor,
            onTap: () => Navigator.of(context).pop(true),
          ),
          gap,
          _SheetButton(
            label: 'Not now',
            height: 44,
            textColor: CafeDetailsTokens.ink,
            onTap: () => Navigator.of(context).pop(false),
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
    this.color,
  });

  final String label;
  final double height;
  final Color? color;
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
          decoration: color == null
              ? null
              : BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(100),
                ),
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
