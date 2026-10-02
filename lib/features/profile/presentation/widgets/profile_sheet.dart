import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

/// The shell every profile bottom sheet uses: 24pt top corners, a grabber, a
/// SemiBold 16 title with an optional close button, then [children] spaced
/// by [gap]. Moves above the keyboard.
class ProfileSheet extends StatelessWidget {
  const ProfileSheet({
    super.key,
    required this.title,
    required this.children,
    this.showClose = true,
    this.onClose,
    this.gap = 4,
  });

  final String title;
  final List<Widget> children;
  final bool showClose;

  /// Defaults to popping the sheet.
  final VoidCallback? onClose;

  /// The sheet's own spacing between grabber, header and content (Figma: 4
  /// on the option sheets, 12 on the confirm sheets).
  final double gap;

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    // The design's 34 bottom padding is the home indicator's space.
    final bottom = math.max(34.0, MediaQuery.viewPaddingOf(context).bottom);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: ProfileTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // The keyboard inset sits inside the surface, so the sheet's colour
      // runs under the keyboard's rounded top corners.
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ProfileTokens.gutter,
            8,
            ProfileTokens.gutter,
            bottom,
          ),
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
                    color: ProfileTokens.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: gap),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: ProfileTokens.text(16, weight: FontWeight.w600),
                    ),
                  ),
                  if (showClose) ...[
                    const SizedBox(width: 12),
                    AdaptiveTap(
                      onTap: onClose ?? () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(16),
                      child: Semantics(
                        button: true,
                        label: 'Close',
                        child: const SizedBox.square(
                          dimension: 32,
                          child: Icon(
                            LucideIcons.x,
                            size: 20,
                            color: ProfileTokens.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              for (final child in children) ...[SizedBox(height: gap), child],
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable line in an options sheet: a Medium 14 title over a muted line
/// saying what it does, with an optional leading icon.
class ProfileSheetOption extends StatelessWidget {
  const ProfileSheetOption({
    super.key,
    required this.title,
    required this.detail,
    required this.onTap,
    this.icon,
    this.destructive = false,
  });

  final String title;
  final String detail;
  final VoidCallback onTap;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final leading = icon;
    final color = destructive ? ProfileTokens.danger : ProfileTokens.ink;
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[
                Icon(leading, size: 20, color: color),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: ProfileTokens.text(
                        14,
                        weight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    Text(
                      detail,
                      style: ProfileTokens.text(12, color: ProfileTokens.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks the user to confirm in a bottom sheet with the profile screens' two
/// button row: an outlined Cancel beside the named action. Resolves true
/// only when the action is tapped.
///
/// [destructive] paints the action red; otherwise it is the brand fill.
Future<bool> showProfileConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) {
  return ProfileSheet.show<bool>(
    context,
    builder: (_) => ProfileConfirmSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  ).then((confirmed) => confirmed ?? false);
}

/// The confirm sheet's body: a question, one muted line, and the two
/// buttons side by side.
class ProfileConfirmSheet extends StatelessWidget {
  const ProfileConfirmSheet({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return ProfileSheet(
      title: title,
      showClose: false,
      gap: 12,
      children: [
        Text(
          message,
          style: ProfileTokens.text(14, color: ProfileTokens.muted),
        ),
        // The 4 spacer the design keeps between two 12 gaps.
        const SizedBox(height: 4),
        ProfileSheetButtons(
          cancelLabel: cancelLabel,
          onCancel: () => Navigator.of(context).pop(false),
          confirmLabel: confirmLabel,
          onConfirm: () => Navigator.of(context).pop(true),
          destructive: destructive,
        ),
      ],
    );
  }
}

/// The two-button row at the foot of a confirm sheet.
class ProfileSheetButtons extends StatelessWidget {
  const ProfileSheetButtons({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
    required this.onCancel,
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    this.busy = false,
    this.busyLabel,
  });

  final String confirmLabel;

  /// Null dims the action.
  final VoidCallback? onConfirm;

  /// Null dims Cancel.
  final VoidCallback? onCancel;
  final String cancelLabel;
  final bool destructive;
  final bool busy;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ProfilePillButton(
            label: cancelLabel,
            onTap: onCancel,
            style: ProfilePillStyle.outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ProfilePillButton(
            label: confirmLabel,
            onTap: onConfirm,
            style: destructive
                ? ProfilePillStyle.danger
                : ProfilePillStyle.brand,
            busy: busy,
            busyLabel: busyLabel,
          ),
        ),
      ],
    );
  }
}
