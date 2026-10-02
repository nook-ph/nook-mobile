import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/state_styles.dart';

/// Full-screen error shell, the shared pattern from Figma "System — offline",
/// "System — server error" and "System — signed out": a 48 tinted circle with
/// a 22 icon, a SemiBold 16 title, a Regular 14 muted line, and one 44 high
/// pill that hugs its label. Signing in is the filled pill; everything else
/// retries with the outlined one.
class FullPageErrorWidget extends StatelessWidget {
  const FullPageErrorWidget({super.key, required this.error, this.onRetry});

  final ErrorInfo error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final signIn = error.type == ErrorType.sessionExpired;
    final retry = onRetry;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: StateStyles.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconFor(error.type),
                  size: 22,
                  color: StateStyles.brand,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.title,
                textAlign: TextAlign.center,
                style: StateStyles.text(16, FontWeight.w600, StateStyles.ink),
              ),
              const SizedBox(height: 8),
              Text(
                error.subtitle,
                textAlign: TextAlign.center,
                style: StateStyles.text(14, FontWeight.w400, StateStyles.muted),
              ),
              if (retry != null) ...[
                // The design's 8 spacer between two 8 gaps.
                const SizedBox(height: 24),
                StatePillButton(
                  label: signIn ? 'Sign in' : 'Try again',
                  filled: signIn,
                  onTap: retry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static IconData iconFor(ErrorType type) {
    return switch (type) {
      ErrorType.offline => LucideIcons.wifiOff,
      ErrorType.sessionExpired => LucideIcons.lock,
      ErrorType.serverError => LucideIcons.triangleAlert,
      ErrorType.unknown => LucideIcons.triangleAlert,
    };
  }
}
