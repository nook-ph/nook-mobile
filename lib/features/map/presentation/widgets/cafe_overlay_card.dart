import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class CafeOverlayCard extends StatelessWidget {
  final CafeSummary cafe;
  final VoidCallback onClose;

  const CafeOverlayCard({super.key, required this.cafe, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close),
                color: colors.textgray,
                splashRadius: 18,
                tooltip: 'Close',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
