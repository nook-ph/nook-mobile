import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';

/// Shared pieces of the redesigned crawl screens: segmented progress, the
/// connected route rows, the bottom-sheet shell and the full-page state view.

/// Destructive text and error strokes on the crawl surfaces.
const crawlDanger = Color(0xFFB3261E);

/// Progress as one segment per stop, so it shows how many stops there are
/// and not only a fraction.
class CrawlSegmentedProgress extends StatelessWidget {
  const CrawlSegmentedProgress({
    super.key,
    required this.done,
    required this.total,
    this.height = 6,
  });

  final int done;
  final int total;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$done of $total stops stamped',
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: i < done ? ListsTokens.brand : crawlTint,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One row of a route: a marker on the left, joined to the next stop by a
/// vertical line, and the stop's content on the right.
///
/// [lineBelow] is null on the last stop; otherwise true draws the connector
/// in the brand colour (already walked) and false in the border colour.
///
/// Figma: the 28pt marker sits at the top of the row, the connector starts 4
/// below it and runs to the row's end; a row that has a connector keeps 18
/// under its text.
class CrawlRouteRow extends StatelessWidget {
  const CrawlRouteRow({
    super.key,
    required this.marker,
    required this.child,
    this.lineBelow,
    this.markerSize = 28,
  });

  final Widget marker;
  final Widget child;
  final bool? lineBelow;
  final double markerSize;

  /// Space kept under the content of a row that leads on to another stop.
  static const double tail = 18;

  @override
  Widget build(BuildContext context) {
    final walked = lineBelow;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: markerSize,
            child: Column(
              children: [
                SizedBox.square(dimension: markerSize, child: marker),
                if (walked != null) ...[
                  const SizedBox(height: 4),
                  Expanded(
                    child: Container(
                      width: 2,
                      decoration: BoxDecoration(
                        color: walked ? ListsTokens.brand : ListsTokens.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: walked == null ? 0 : tail),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// The shell every crawl bottom sheet uses: 24pt top corners, a grabber, an
/// optional title with a close button, then [child].
class CrawlSheet extends StatelessWidget {
  const CrawlSheet({
    super.key,
    this.title,
    required this.child,
    this.showClose = true,
    this.gap = 4,
  });

  final String? title;
  final Widget child;
  final bool showClose;

  /// The sheet's own spacing between grabber, header and content (Figma: 4
  /// on the option and edit sheets, 14 on the code and invite sheets).
  final double gap;

  /// Opens [builder]'s widget as a modal sheet that grows with its content
  /// and moves above the keyboard.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  /// The 36 x 4 handle with the 4 the design keeps under it.
  static Widget grabber() => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: ListsTokens.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final heading = title;
    final hasHeader = heading != null || showClose;
    return Container(
      decoration: const BoxDecoration(
        color: ListsTokens.surface,
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                grabber(),
                if (hasHeader) ...[
                  // The header is 24 tall in the design. It is drawn 32 tall
                  // here so the close button keeps a usable target, and the
                  // 4 that adds on each side is taken out of the gaps.
                  SizedBox(height: gap > 4 ? gap - 4 : 0),
                  SizedBox(
                    height: 32,
                    child: Row(
                      children: [
                        Expanded(
                          child: heading == null
                              ? const SizedBox.shrink()
                              : Text(
                                  heading,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: crawlText(16, weight: FontWeight.w600),
                                ),
                        ),
                        if (showClose) ...[
                          const SizedBox(width: 12),
                          AdaptiveTap(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(22),
                            child: Semantics(
                              button: true,
                              label: 'Close',
                              child: const SizedBox(
                                width: 44,
                                height: 32,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Icon(
                                    LucideIcons.x,
                                    size: 22,
                                    color: ListsTokens.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: gap > 4 ? gap - 4 : 0),
                ],
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tappable line in an options sheet: a title, and what it does underneath.
class CrawlSheetAction extends StatelessWidget {
  const CrawlSheetAction({
    super.key,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        // Full width so the row starts at the left edge: on iOS the tap
        // target is a CupertinoButton, which centres a narrower child.
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: crawlText(
                  14,
                  weight: FontWeight.w500,
                  color: destructive ? crawlDanger : ListsTokens.ink,
                ),
              ),
              if (note != null)
                Text(note, style: crawlText(12, color: ListsTokens.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-page state: nothing here, could not load, gone. One icon, one
/// title, one line, and up to two ways forward.
class CrawlStateView extends StatelessWidget {
  const CrawlStateView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.primaryLabel,
    this.onPrimary,
    this.primaryFilled = false,
    this.secondaryLabel,
    this.onSecondary,
    this.top = 150,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  /// Filled brand button instead of the outlined one, for "Sign in".
  final bool primaryFilled;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Distance from the top of the body to the icon (Figma: 150 on the run
  /// page, 170 on crawl detail).
  final double top;

  /// The icon each failure type uses across the app's error states.
  static IconData get offlineIcon => LucideIcons.wifiOff;
  static IconData get lockedIcon => LucideIcons.lock;
  static IconData get alertIcon => LucideIcons.triangleAlert;
  static IconData get goneIcon => LucideIcons.mapPin;

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    final primary = primaryLabel;
    final secondary = secondaryLabel;
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(40, top, 40, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: crawlTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 29, color: ListsTokens.brand),
            ),
            // Figma: 8 + an 8 spacer + 8.
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: crawlText(16, weight: FontWeight.w600),
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(
                note,
                textAlign: TextAlign.center,
                style: crawlText(14, color: ListsTokens.muted),
              ),
            ],
            if (primary != null) ...[
              // Figma: 8 + a 12 spacer + 8.
              const SizedBox(height: 28),
              CrawlPillButton(
                label: primary,
                onTap: onPrimary,
                height: 44,
                fontSize: 14,
                outlined: !primaryFilled,
              ),
            ],
            if (secondary != null) ...[
              const SizedBox(height: 4),
              CrawlTextButton(label: secondary, onTap: onSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

/// A quiet text action ("Not now", "Enter a code").
class CrawlTextButton extends StatelessWidget {
  const CrawlTextButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = ListsTokens.brand,
    this.fontSize = 14,
    this.minHeight = 44,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double fontSize;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Center(
          widthFactor: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: crawlText(fontSize, weight: FontWeight.w500, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// The two-button dialog of the crawl screens ("Archive this crawl?",
/// "Leave this run?"): 20 radius, 20 padding, text buttons on the right.
class CrawlConfirmDialog extends StatelessWidget {
  const CrawlConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final String body;
  final String cancelLabel;
  final String confirmLabel;

  /// Resolves true when the destructive action is chosen.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String body,
    required String cancelLabel,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CrawlConfirmDialog(
        title: title,
        body: body,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
      ),
    ).then((confirmed) => confirmed ?? false);
  }

  @override
  Widget build(BuildContext context) {
    Widget action(String label, Color color, bool result) => AdaptiveTap(
      onTap: () => Navigator.of(context).pop(result),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        child: Text(
          label,
          style: crawlText(14, weight: FontWeight.w500, color: color),
        ),
      ),
    );

    return Dialog(
      backgroundColor: ListsTokens.surface,
      surfaceTintColor: ListsTokens.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: crawlText(16, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(body, style: crawlText(14, color: ListsTokens.muted)),
            // Figma: 8 + an 8 spacer + 8.
            const SizedBox(height: 24),
            // A Wrap, so long labels at a large text size drop to a second
            // line instead of overflowing.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  action(cancelLabel, ListsTokens.ink, false),
                  action(confirmLabel, crawlDanger, true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An inline notice above content ("Location is off") with one action.
class CrawlBanner extends StatelessWidget {
  const CrawlBanner({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = actionLabel;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: crawlTint,
        borderRadius: BorderRadius.circular(ListsTokens.radius),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ListsTokens.ink),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: crawlText(12))),
          if (action != null)
            CrawlTextButton(label: action, onTap: onAction, fontSize: 12),
        ],
      ),
    );
  }
}

/// A grey block standing in for content that is still loading.
class CrawlSkeleton extends StatelessWidget {
  const CrawlSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: crawlTint,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A text field with the crawl screens' states: focus, error with a message
/// underneath, a helper line, and an optional character count.
class CrawlTextField extends StatelessWidget {
  const CrawlTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.maxLength,
    this.maxLines = 1,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.quietLabel = false,
    this.counterInside = false,
    this.gap = 12,
    this.emphasisWidth = 1.5,
    this.textStyle,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? errorText;

  /// Shown under the field in the muted colour when there is no error.
  final String? helperText;
  final int? maxLength;

  /// Null lets the field grow with its text.
  final int? maxLines;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  /// The builder's label: 12 Regular in the muted colour, instead of the
  /// sheets' 12 Medium ink.
  final bool quietLabel;

  /// Puts the count inside the field at 10pt (the builder) instead of beside
  /// the label at 12pt (the edit sheet).
  final bool counterInside;

  /// Space between label, field and the line under it.
  final double gap;

  /// Stroke of the focused and error borders.
  final double emphasisWidth;
  final TextStyle? textStyle;

  /// "19/60".
  static String counterText(int length, int limit) => '$length/$limit';

  @override
  Widget build(BuildContext context) {
    final heading = label;
    final error = errorText;
    final helper = helperText;
    final limit = maxLength;
    final below = error ?? helper;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      borderSide: BorderSide(color: color, width: width),
    );

    Widget counter(double size) => ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final length = value.text.characters.length;
        return Text(
          counterText(length, limit!),
          // The field stops at the limit, so reaching it is not an error:
          // the count only turns from muted to ink.
          style: crawlText(
            size,
            color: length >= limit ? ListsTokens.ink : ListsTokens.muted,
          ),
        );
      },
    );

    final showLabelRow = heading != null || (limit != null && !counterInside);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabelRow)
          Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    heading ?? '',
                    style: quietLabel
                        ? crawlText(12, color: ListsTokens.muted)
                        : crawlText(12, weight: FontWeight.w500),
                  ),
                ),
                if (limit != null && !counterInside) counter(12),
              ],
            ),
          ),
        TextField(
          controller: controller,
          autofocus: autofocus,
          maxLines: maxLines,
          minLines: 1,
          maxLength: limit,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          cursorColor: ListsTokens.brand,
          style: textStyle ?? crawlText(14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: (textStyle ?? crawlText(14)).copyWith(
              color: ListsTokens.muted,
              fontWeight: FontWeight.w400,
            ),
            counterText: '',
            isDense: true,
            filled: true,
            fillColor: ListsTokens.surface,
            // Figma: 13 / 14 inside the stroke.
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13 + emphasisWidth,
            ),
            suffixIcon: limit != null && counterInside
                ? Padding(
                    padding: const EdgeInsets.only(left: 8, right: 14),
                    child: counter(10),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(),
            enabledBorder: error == null
                ? border(ListsTokens.border, 1)
                : border(crawlDanger, emphasisWidth),
            focusedBorder: error == null
                ? border(ListsTokens.brand, emphasisWidth)
                : border(crawlDanger, emphasisWidth),
          ),
        ),
        if (below != null)
          Padding(
            padding: EdgeInsets.only(top: gap),
            child: Text(
              below,
              style: crawlText(
                12,
                color: error != null ? crawlDanger : ListsTokens.muted,
              ),
            ),
          ),
      ],
    );
  }
}
