import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';

/// The cafe page when it cannot be shown: a back arrow, an icon in a tinted
/// circle, a title, one line of help and one or two pill buttons.
///
/// Used for the app's four load errors (offline, signed out, server,
/// anything else) and for a cafe that no longer exists.
class CafeDetailsErrorView extends StatelessWidget {
  const CafeDetailsErrorView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onBack,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// One of the app's error types, with "Sign in" for a lapsed session and
  /// "Try again" otherwise.
  factory CafeDetailsErrorView.forError({
    Key? key,
    required ErrorInfo info,
    required VoidCallback onRetry,
    required VoidCallback onSignIn,
    required VoidCallback onBack,
  }) {
    final signedOut = info.type == ErrorType.sessionExpired;
    return CafeDetailsErrorView(
      key: key,
      icon: switch (info.type) {
        ErrorType.offline => LucideIcons.wifiOff,
        ErrorType.sessionExpired => LucideIcons.lock,
        ErrorType.serverError || ErrorType.unknown => LucideIcons.triangleAlert,
      },
      title: info.title,
      message: info.subtitle,
      primaryLabel: signedOut ? 'Sign in' : 'Try again',
      onPrimary: signedOut ? onSignIn : onRetry,
      onBack: onBack,
    );
  }

  /// A removed or missing cafe.
  factory CafeDetailsErrorView.notFound({
    Key? key,
    required VoidCallback onSearch,
    required VoidCallback onHome,
    required VoidCallback onBack,
  }) {
    return CafeDetailsErrorView(
      key: key,
      icon: LucideIcons.triangleAlert,
      title: 'This cafe is no longer on Nook',
      message: 'It may have closed or been removed.',
      primaryLabel: 'Search cafes',
      onPrimary: onSearch,
      secondaryLabel: 'Back to home',
      onSecondary: onHome,
      onBack: onBack,
    );
  }

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final VoidCallback onBack;

  static const background = Color(0xFFFEFEFE);
  static const _muted = Color(0xFF868584);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const gap = SizedBox(height: 8);
    final secondary = secondaryLabel;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: 'Back',
                  child: AdaptiveTap(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(11),
                    child: const Icon(
                      LucideIcons.arrowLeft,
                      size: 22,
                      color: CafeDetailsTokens.ink,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 210, 40, 24),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: CafeDetailsTokens.tint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 26,
                        color: CafeDetailsTokens.brand,
                      ),
                    ),
                    gap,
                    const SizedBox(height: 8),
                    gap,
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: CafeDetailsTokens.ink,
                      ),
                    ),
                    gap,
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: _muted,
                      ),
                    ),
                    gap,
                    const SizedBox(height: 12),
                    gap,
                    _PillButton(
                      label: primaryLabel,
                      onTap: onPrimary,
                      filled: true,
                    ),
                    if (secondary != null) ...[
                      gap,
                      _PillButton(
                        label: secondary,
                        onTap: onSecondary ?? () {},
                        filled: false,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: filled
                ? CafeDetailsTokens.brand
                : CafeDetailsErrorView.background,
            borderRadius: BorderRadius.circular(100),
            border: filled ? null : Border.all(color: CafeDetailsTokens.border),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: filled
                    ? CafeDetailsErrorView.background
                    : CafeDetailsTokens.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
