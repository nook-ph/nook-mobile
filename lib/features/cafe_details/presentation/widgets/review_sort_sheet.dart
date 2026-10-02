import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_logic.dart';

/// Sort order for the reviews list. A tap applies and closes; there is no
/// Apply button.
class ReviewSortSheet extends StatelessWidget {
  const ReviewSortSheet({super.key, required this.current});

  final String current;

  /// Returns the chosen sort value, or null when dismissed.
  static Future<String?> show(BuildContext context, {required String current}) {
    return ReviewSheetShell.show<String>(
      context,
      builder: (_) => ReviewSortSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReviewSheetShell(
      title: 'Sort by',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in reviewSortOptions)
            AdaptiveTap(
              onTap: () => Navigator.of(context).pop(option.value),
              borderRadius: BorderRadius.circular(12),
              child: Semantics(
                button: true,
                selected: option.value == current,
                // 47 tall in Figma with a 4 gap; the gap is folded into the
                // row so the whole 51 is tappable.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 51),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          option.label,
                          style:
                              (option.value == current
                                      ? context.textTheme.bodyMediumMed
                                      : context.textTheme.bodyMedium)
                                  ?.copyWith(
                                    color: ReviewTokens.ink,
                                    fontSize: 14,
                                  ),
                        ),
                      ),
                      if (option.value == current)
                        const Icon(
                          LucideIcons.check,
                          size: 18,
                          color: ReviewTokens.brand,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
