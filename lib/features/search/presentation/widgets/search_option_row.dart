import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';

/// 60pt option: 40pt grey circle with an icon, title, optional subtitle,
/// optional trailing widget. Shared by the "Search near" sheet, the place
/// results and the saved-place editor.
class SearchOptionRow extends StatelessWidget {
  const SearchOptionRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.subtitleColor = SearchTokens.muted,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    final end = trailing;
    return AdaptiveTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: SearchTokens.field,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SearchTokens.text(context, weight: FontWeight.w500),
                  ),
                  if (sub != null && sub.isNotEmpty)
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SearchTokens.text(
                        context,
                        size: 12,
                        color: subtitleColor,
                      ),
                    ),
                ],
              ),
            ),
            if (end != null) ...[const SizedBox(width: 8), end],
          ],
        ),
      ),
    );
  }
}

/// A 44pt square, icon-only button for the end of a row ("More", "Clear").
class SearchIconButton extends StatelessWidget {
  const SearchIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = SearchTokens.ink,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
