import 'package:flutter/material.dart';
import 'package:nook/core/widgets/error/state_styles.dart';

/// Compact empty state for a subsection, Figma "System — section states":
/// a tinted radius 12 block with 14 padding, a Medium 14 title and a
/// Regular 12 muted line 2 below it. Left aligned, no icon.
class SectionEmptyWidget extends StatelessWidget {
  const SectionEmptyWidget({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
  });

  final String title;
  final String subtitle;

  /// Kept for older call sites. The redesigned block has no icon, so this is
  /// not drawn.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StateStyles.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: StateStyles.text(14, FontWeight.w500, StateStyles.ink),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: StateStyles.text(12, FontWeight.w400, StateStyles.muted),
          ),
        ],
      ),
    );
  }
}
