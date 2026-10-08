import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Shared pieces of the redesigned Lists screens: the bottom-sheet shell, the
/// pill buttons, photo thumbnails, the hairline and skeleton blocks.

/// The shell every Lists bottom sheet uses: 24pt top corners, a grabber, a
/// header (optional back, title, optional [trailing], close), then
/// [children] spaced [gap] apart. [footer] stays pinned under the scrolling
/// content. Moves above the keyboard.
class ListsSheet extends StatelessWidget {
  const ListsSheet({
    super.key,
    this.title,
    this.onBack,
    this.trailing,
    this.onClose,
    this.gap = 12,
    required this.children,
    this.footer,
  });

  final String? title;

  /// Shows a back arrow before the title and centres the title between it
  /// and the close button.
  final VoidCallback? onBack;

  /// Sits between the title and the close button ("New list").
  final Widget? trailing;

  /// Defaults to popping the sheet.
  final VoidCallback? onClose;

  /// The sheet's own spacing between grabber, header and each child.
  final double gap;
  final List<Widget> children;
  final Widget? footer;

  /// Opens [builder]'s widget as a modal sheet that grows with its content.
  /// With [isDismissible] false, neither a tap outside nor a drag closes
  /// it; its own close button and Back still can.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final heading = title;
    final back = onBack;
    final extra = trailing;
    final pinned = footer;

    return Container(
      decoration: const BoxDecoration(
        color: ListsTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // The keyboard inset sits inside the surface, so the sheet's colour
      // runs under the keyboard: its rounded top corners would otherwise
      // show the dimmed page behind them.
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ListsTokens.gutter,
              8,
              ListsTokens.gutter,
              16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The 36 x 4 handle with the 4 the design keeps under it.
                Padding(
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
                ),
                SizedBox(height: gap),
                // At least 32; grows with the title at large text (a fixed
                // 32 clipped the 16pt title from about 1.33x).
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 32),
                  child: Row(
                    children: [
                      if (back != null) ...[
                        _HeaderIcon(
                          icon: LucideIcons.arrowLeft,
                          size: 20,
                          label: 'Back',
                          onTap: back,
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: heading == null
                            ? const SizedBox.shrink()
                            : Text(
                                heading,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: back == null
                                    ? TextAlign.start
                                    : TextAlign.center,
                                style: listsText(16, weight: FontWeight.w600),
                              ),
                      ),
                      if (extra != null) ...[const SizedBox(width: 12), extra],
                      const SizedBox(width: 12),
                      _HeaderIcon(
                        icon: LucideIcons.x,
                        size: 22,
                        label: 'Close',
                        onTap: onClose ?? () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final child in children) ...[
                          SizedBox(height: gap),
                          child,
                        ],
                      ],
                    ),
                  ),
                ),
                if (pinned != null) ...[SizedBox(height: gap), pinned],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 32 header control. The tap target reaches past the drawn box so it
/// stays usable at the design's size.
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.size,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox.square(
          dimension: 32,
          child: Icon(icon, size: size, color: ListsTokens.ink),
        ),
      ),
    );
  }
}

/// One line of an options sheet: a Medium 14 title and, under it, what the
/// action does. [destructive] paints the title red.
class ListsSheetAction extends StatelessWidget {
  const ListsSheetAction({
    super.key,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final note = subtitle;
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: listsText(
                14,
                weight: FontWeight.w500,
                color: destructive ? ListsTokens.danger : ListsTokens.ink,
              ),
            ),
            if (note != null)
              Text(note, style: listsText(12, color: ListsTokens.muted)),
          ],
        ),
      ),
    );
  }
}

enum ListsPillStyle { filled, outlined, danger }

/// The pill button of the Lists screens: brand fill, white with a hairline,
/// or red fill. Dimmed to 40% when [onTap] is null; [busy] swaps the label
/// for a spinner and ignores taps.
class ListsPillButton extends StatelessWidget {
  const ListsPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.style = ListsPillStyle.filled,
    this.height = 48,
    this.icon,
    this.fontSize = 14,
    this.horizontalPadding = 16,
    this.expand = true,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final ListsPillStyle style;
  final double height;
  final IconData? icon;
  final double fontSize;
  final double horizontalPadding;

  /// Fills the available width. When false the pill hugs its label.
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final outlined = style == ListsPillStyle.outlined;
    final foreground = outlined ? ListsTokens.ink : ListsTokens.surface;
    final fill = switch (style) {
      ListsPillStyle.filled => ListsTokens.brand,
      ListsPillStyle.outlined => ListsTokens.surface,
      ListsPillStyle.danger => ListsTokens.danger,
    };
    final glyph = icon;
    final action = busy ? null : onTap;

    final content = busy
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (glyph != null) ...[
                Icon(glyph, size: fontSize, color: foreground),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: listsText(
                    fontSize,
                    weight: FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: action != null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: AdaptiveTap(
          onTap: action,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            height: height,
            width: expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(100),
              border: outlined ? Border.all(color: ListsTokens.border) : null,
            ),
            child: Center(widthFactor: expand ? null : 1, child: content),
          ),
        ),
      ),
    );
  }
}

/// A quiet text action centred in a 44 target ("Skip for now", "Done").
class ListsTextButton extends StatelessWidget {
  const ListsTextButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                label,
                style: listsText(
                  14,
                  weight: FontWeight.w500,
                  color: ListsTokens.brand,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A square cafe or list photo. With no usable [imageUrl] it is a tinted
/// tile carrying [placeholderIcon].
class ListsThumb extends StatelessWidget {
  const ListsThumb({
    super.key,
    required this.imageUrl,
    required this.size,
    this.radius = 12,
    this.placeholderIcon = LucideIcons.coffee,
  });

  final String? imageUrl;
  final double size;
  final double radius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null || url.isEmpty
          ? Container(
              width: size,
              height: size,
              color: ListsTokens.tint,
              alignment: Alignment.center,
              child: Icon(
                placeholderIcon,
                size: size >= 56 ? 20 : 18,
                color: ListsTokens.muted,
              ),
            )
          : CafeCardImage(imageUrl: url, height: size, width: size),
    );
  }
}

/// 1pt #e0e0e0 rule.
class ListsDivider extends StatelessWidget {
  const ListsDivider({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: ListsTokens.border,
    child: SizedBox(height: 1, width: double.infinity),
  );
}

/// A grey block standing in for content that is still loading.
class ListsSkeleton extends StatelessWidget {
  const ListsSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
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
        color: ListsTokens.tint,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// The page header of a pushed Lists screen: a back arrow, and the ⋯ when
/// [onMore] is set.
class ListsNavBar extends StatelessWidget implements PreferredSizeWidget {
  const ListsNavBar({super.key, this.onMore});

  final VoidCallback? onMore;

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context) {
    final more = onMore;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 44,
        child: Padding(
          // 20 to the glyph: the 44 targets overhang the gutter by 11 / 12.
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Back',
                child: AdaptiveTap(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(22),
                  child: const SizedBox.square(
                    dimension: 44,
                    child: Icon(
                      LucideIcons.arrowLeft,
                      size: 22,
                      color: ListsTokens.ink,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (more != null)
                Semantics(
                  button: true,
                  label: 'List options',
                  child: AdaptiveTap(
                    onTap: more,
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        PhosphorIconsFill.dotsThreeOutline,
                        size: 20,
                        color: ListsTokens.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
