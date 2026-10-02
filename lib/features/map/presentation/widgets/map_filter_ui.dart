import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/debounced_count.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';

/// Shared pieces of the map filter sheets: the sheet frame with grabber and
/// title, the selectable chip, the chip wrap, and the Clear all / Apply footer.

/// White sheet with 24pt top corners, a 36x4 grabber, the title and a close
/// button, then [body] and an optional [footer].
class MapFilterSheetFrame extends StatelessWidget {
  const MapFilterSheetFrame({
    super.key,
    required this.title,
    required this.body,
    this.footer,
    this.height,
  });

  final String title;
  final Widget body;
  final Widget? footer;

  /// Fixed height for the full filter sheet; null hugs the content.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final foot = footer;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: MapTokens.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MapTokens.gutter),
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: MapTokens.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: 'Close',
                  excludeSemantics: true,
                  child: AdaptiveTap(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(22),
                    child: const SizedBox.square(
                      dimension: 32,
                      child: Icon(
                        LucideIcons.x,
                        size: 20,
                        color: MapTokens.ink,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (height != null) Expanded(child: body) else Flexible(child: body),
        ?foot,
      ],
    );

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: MapTokens.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: content,
    );
  }
}

/// A filter choice: white outlined pill, filled green when selected.
class MapFilterChoiceChip extends StatelessWidget {
  const MapFilterChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? MapTokens.brand : MapTokens.surface,
            borderRadius: BorderRadius.circular(100),
            border: selected ? null : Border.all(color: MapTokens.border),
          ),
          // widthFactor 1 centres the label vertically without the chip
          // growing to the Wrap's full width (a bare `alignment` would).
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? MapTokens.surface : MapTokens.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chips that wrap onto as many lines as they need, 8pt apart both ways.
class MapFilterChipWrap extends StatelessWidget {
  const MapFilterChipWrap({
    super.key,
    required this.labels,
    required this.isSelected,
    required this.onTap,
  });

  final List<String> labels;
  final bool Function(String label) isSelected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          MapFilterChoiceChip(
            label: label,
            selected: isSelected(label),
            onTap: () => onTap(label),
          ),
      ],
    );
  }
}

/// "Sort by", "Best for": the 14pt heading over a group of chips.
class MapFilterSectionTitle extends StatelessWidget {
  const MapFilterSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: MapTokens.ink,
      ),
    );
  }
}

/// Top-bordered footer: "Clear all" as text, then the primary pill.
///
/// The pill reads "Show N cafes" while [count] holds a number, and "Apply"
/// while it is null (still counting, failed, or not countable).
class MapFilterFooter extends StatelessWidget {
  const MapFilterFooter({
    super.key,
    required this.onClear,
    required this.onApply,
    this.count,
  });

  final VoidCallback onClear;
  final VoidCallback onApply;
  final ValueListenable<int?>? count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        MapTokens.gutter,
        12,
        MapTokens.gutter,
        bottomInset > 0 ? bottomInset + 12 : 24,
      ),
      decoration: const BoxDecoration(
        color: MapTokens.surface,
        border: Border(top: BorderSide(color: MapTokens.border)),
      ),
      child: Row(
        children: [
          AdaptiveTap(
            onTap: onClear,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    'Clear all',
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MapTokens.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AdaptiveTap(
              onTap: onApply,
              borderRadius: BorderRadius.circular(100),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MapTokens.brand,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: ValueListenableBuilder<int?>(
                  valueListenable: count ?? const AlwaysStoppedAnimation(null),
                  builder: (context, n, _) => Text(
                    showCafesLabel(n),
                    maxLines: 1,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: MapTokens.surface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
