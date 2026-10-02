import 'package:flutter/material.dart';

/// Colours and type of the search redesign (Figma "Search — redesign").
class SearchTokens {
  const SearchTokens._();

  static const ink = Color(0xFF0A0F0D);
  static const muted = Color(0xFF868584);
  static const brand = Color(0xFF344E41);
  static const star = Color(0xFF588157);
  static const closed = Color(0xFFB3261E);
  static const border = Color(0xFFE0E0E0);
  static const surface = Color(0xFFFEFEFE);
  static const field = Color(0xFFEEEEEE);

  static const gutter = 20.0;

  /// Poppins at [size] with Figma's auto line height (1.5).
  static TextStyle text(
    BuildContext context, {
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = ink,
  }) {
    return (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
        .copyWith(
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: 1.5,
        );
  }
}

/// 1pt #e0e0e0 rule.
class SearchDivider extends StatelessWidget {
  const SearchDivider({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: SearchTokens.border,
    child: SizedBox(height: 1, width: double.infinity),
  );
}

/// A 34pt pill chip: outlined at rest, filled green when [selected].
class SearchChip extends StatelessWidget {
  const SearchChip({
    super.key,
    this.label,
    this.icon,
    this.trailingIcon,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  final String? label;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool selected;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? SearchTokens.surface : SearchTokens.ink;
    final text = label;
    final leading = icon;
    final trailing = trailingIcon;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? SearchTokens.brand : null,
            borderRadius: BorderRadius.circular(100),
            border: selected ? null : Border.all(color: SearchTokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) Icon(leading, size: 14, color: fg),
              if (text != null)
                Text(
                  text,
                  style: SearchTokens.text(context, size: 12, color: fg),
                ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                Icon(trailing, size: 14, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
