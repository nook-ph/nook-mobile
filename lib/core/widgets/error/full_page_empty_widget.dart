import 'package:flutter/material.dart';
import 'package:nook/core/widgets/error/state_styles.dart';

/// Full-screen empty state, Figma "System — empty page": no icon, a SemiBold
/// 16 title, a Regular 14 muted line, and an optional filled 44 pill.
class FullPageEmptyWidget extends StatelessWidget {
  const FullPageEmptyWidget({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;

  /// Kept for older call sites. The redesigned empty page has no icon, so
  /// this is not drawn.
  final IconData? icon;

  /// The pill's label. The pill shows only when [onAction] is set too.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: StateStyles.text(16, FontWeight.w600, StateStyles.ink),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: StateStyles.text(14, FontWeight.w400, StateStyles.muted),
              ),
              if (label != null && action != null) ...[
                // The design's 8 spacer between two 8 gaps.
                const SizedBox(height: 24),
                StatePillButton(label: label, filled: true, onTap: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
