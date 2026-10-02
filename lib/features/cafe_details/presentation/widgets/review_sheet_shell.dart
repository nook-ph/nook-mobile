import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';

/// Colours and the bottom-sheet shell shared by the review surfaces (the
/// reviews page, the sort sheet, write a review, options and report).
class ReviewTokens {
  const ReviewTokens._();

  static const brand = Color(0xFF344E41);

  /// Non-text only: the rating star and the helpful mark.
  static const star = Color(0xFF588157);
  static const ink = Color(0xFF0A0F0D);
  static const muted = Color(0xFF767574);

  /// Figma's grey for icons and disabled labels. Too light for body text.
  static const mutedIcon = Color(0xFF868584);
  static const border = Color(0xFFE0E0E0);
  static const surface = Color(0xFFFEFEFE);
  static const tint = Color(0xFFEEEEEE);
  static const danger = Color(0xFFB3261E);
  static const dangerTint = Color(0xFFFBEDEC);

  static const gutter = 20.0;
}

/// The shell every review sheet uses: 24pt top corners, a grabber, an
/// optional title with a close button, then [child]. Moves above the
/// keyboard and scrolls when the content is taller than the screen.
class ReviewSheetShell extends StatelessWidget {
  const ReviewSheetShell({
    super.key,
    this.title,
    required this.child,
    this.showClose = true,
    this.onClose,
  });

  final String? title;
  final Widget child;
  final bool showClose;

  /// Defaults to popping the sheet.
  final VoidCallback? onClose;

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final heading = title;
    return Container(
      decoration: const BoxDecoration(
        color: ReviewTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // The keyboard inset sits inside the surface, so the sheet's colour
      // runs under the keyboard's rounded top corners.
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              ReviewTokens.gutter,
              8,
              ReviewTokens.gutter,
              16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ReviewTokens.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (heading != null || showClose)
                  Row(
                    children: [
                      Expanded(
                        child: heading == null
                            ? const SizedBox.shrink()
                            : Text(
                                heading,
                                style: context.textTheme.bodyLargeSemi.copyWith(
                                  color: ReviewTokens.ink,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                      if (showClose)
                        AdaptiveTap(
                          onTap: onClose ?? () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(22),
                          child: Semantics(
                            button: true,
                            label: 'Close',
                            child: const SizedBox.square(
                              dimension: 44,
                              child: Icon(
                                Icons.close,
                                size: 22,
                                color: ReviewTokens.ink,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width pill button. Grey when [onTap] is null. While [busy] it shows
/// a spinner, or a grey "spinner + [busyLabel]" when a label is given.
class ReviewPrimaryButton extends StatelessWidget {
  const ReviewPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.busyLabel,
    this.color = ReviewTokens.brand,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;
  final String? busyLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final working = busyLabel;
    final grey = busy ? working != null : !enabled;
    final foreground = grey ? ReviewTokens.mutedIcon : ReviewTokens.surface;
    final textStyle = context.textTheme.bodyMediumMed.copyWith(
      color: foreground,
      fontSize: 14,
    );
    final spinner = SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      child: AdaptiveTap(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 48,
          width: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: grey ? ReviewTokens.tint : color,
            borderRadius: BorderRadius.circular(999),
          ),
          child: busy
              ? (working == null
                    ? spinner
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          spinner,
                          const SizedBox(width: 8),
                          Text(working, style: textStyle),
                        ],
                      ))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: foreground),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// The quiet second action under a [ReviewPrimaryButton]: "Cancel".
class ReviewTextButton extends StatelessWidget {
  const ReviewTextButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 48,
          width: double.infinity,
          alignment: Alignment.center,
          child: Text(
            label,
            style: context.textTheme.bodyMediumMed.copyWith(
              color: ReviewTokens.ink,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of five stars, filled up to [rating].
class ReviewStars extends StatelessWidget {
  const ReviewStars({super.key, required this.rating, this.size = 14});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$rating out of 5 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= rating ? Icons.star : Icons.star_border,
              size: size,
              color: i <= rating ? ReviewTokens.star : const Color(0xFFC4C4C4),
            ),
        ],
      ),
    );
  }
}
