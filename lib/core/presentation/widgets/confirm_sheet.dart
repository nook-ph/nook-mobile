import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/widgets/error/state_styles.dart';

/// Asks the user to confirm an action in a bottom sheet (Figma "System —
/// confirm sheet"). Resolves true only when the confirm pill is tapped;
/// cancelling, dragging the sheet down or tapping the scrim resolves false.
///
/// [destructive] paints the confirm pill red; otherwise it is the brand fill.
Future<bool> showConfirmSheet(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    builder: (_) => ConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  ).then((confirmed) => confirmed ?? false);
}

/// The sheet body: grabber, a centred SemiBold 20 question, one Regular 14
/// muted line, a 48 filled confirm pill and a 48 text cancel.
class ConfirmSheet extends StatelessWidget {
  const ConfirmSheet({
    super.key,
    required this.title,
    this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.destructive = true,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final body = message;
    // The design's 34 bottom padding is the home indicator's space.
    final bottom = math.max(34.0, MediaQuery.viewPaddingOf(context).bottom);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: StateStyles.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: StateStyles.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 8 sheet gap + the copy block's 8 top padding.
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: StateStyles.text(20, FontWeight.w600, StateStyles.ink),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: StateStyles.text(14, FontWeight.w400, StateStyles.muted),
            ),
          ],
          // The copy block's 12 bottom padding + 8 sheet gap.
          const SizedBox(height: 20),
          _SheetButton(
            label: confirmLabel,
            fill: destructive ? StateStyles.danger : StateStyles.brand,
            color: StateStyles.surface,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          _SheetButton(
            label: cancelLabel,
            color: StateStyles.ink,
            onTap: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

/// 48 high full-width pill with a Medium 14 label; no fill means text only.
class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.fill,
  });

  final String label;
  final Color color;
  final Color? fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: StateStyles.text(14, FontWeight.w500, color),
          ),
        ),
      ),
    );
  }
}
