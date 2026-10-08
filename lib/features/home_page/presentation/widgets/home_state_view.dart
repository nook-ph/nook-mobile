import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// What fills the feed area when there is no feed: offline, signed out, a
/// server error, or nothing to show. The top bar and tabs stay around it.
class HomeStateView extends StatelessWidget {
  const HomeStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.primaryAction = false,
    this.iconSize = 29,
    this.iconColor,
  });

  /// Nothing to show and nothing failed (Figma 1605:14372).
  const HomeStateView.noCafes({super.key})
    : icon = LucideIcons.house,
      title = 'No cafes yet',
      subtitle = 'Pull to refresh. New spots appear here soon.',
      actionLabel = null,
      onAction = null,
      primaryAction = false,
      iconSize = 26,
      iconColor = const Color(0xFF868584);

  /// The app's copy for [error], with the icon for its type. Signing in is
  /// the one action drawn as a filled button.
  factory HomeStateView.error({
    Key? key,
    required ErrorInfo error,
    required VoidCallback onRetry,
  }) {
    final signedOut = error.type == ErrorType.sessionExpired;
    return HomeStateView(
      key: key,
      icon: iconFor(error.type),
      title: error.title,
      subtitle: error.subtitle,
      actionLabel: signedOut ? 'Sign in' : 'Try again',
      onAction: onRetry,
      primaryAction: signedOut,
    );
  }

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Filled brand button instead of the outlined one.
  final bool primaryAction;

  final double iconSize;

  /// Defaults to the brand green.
  final Color? iconColor;

  /// The copy the feed shows for a failed load. A server fault gets Home's
  /// own wording (Figma 1605:14313); offline and signed out keep the app's.
  static ErrorInfo errorCopy(Object error) {
    final info = AppErrorCopy.fromException(error);
    return switch (info.type) {
      ErrorType.offline || ErrorType.sessionExpired => info,
      ErrorType.serverError || ErrorType.unknown => ErrorInfo(
        type: info.type,
        title: "We couldn't load cafes",
        subtitle: 'Something went wrong on our side. Try again.',
      ),
    };
  }

  static IconData iconFor(ErrorType type) => switch (type) {
    ErrorType.offline => LucideIcons.wifiOff,
    ErrorType.sessionExpired => LucideIcons.lock,
    ErrorType.serverError => LucideIcons.triangleAlert,
    ErrorType.unknown => LucideIcons.triangleAlert,
  };

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final scheme = context.colorScheme;
    // Full width: the feed's scroll view starts its children on the left, so
    // a block as wide as its longest line sat off-centre.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: scheme.offWhite,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor ?? scheme.primary100,
            ),
          ),
          // Figma: 8 + a 6 spacer + 8.
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLargeSemi.copyWith(
              color: scheme.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: scheme.gray,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (label != null) ...[
            // Figma: 8 + a 10 spacer + 8.
            const SizedBox(height: 26),
            AdaptiveTap(
              onTap: onAction,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: primaryAction ? scheme.primary100 : scheme.white,
                  borderRadius: BorderRadius.circular(999),
                  border: primaryAction
                      ? null
                      : Border.all(color: scheme.border),
                ),
                // widthFactor keeps the pill as wide as its label.
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: context.textTheme.bodyMediumMed.copyWith(
                      fontSize: 14,
                      height: 1.5,
                      color: primaryAction ? scheme.white : scheme.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
