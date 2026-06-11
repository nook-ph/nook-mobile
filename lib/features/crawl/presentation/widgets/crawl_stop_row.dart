import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stop.dart';

class CrawlStopRow extends StatelessWidget {
  final CrawlStop stop;

  const CrawlStopRow({
    super.key,
    required this.stop,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final isClaimed = stop.isClaimed;
    final stopNumber = stop.stopOrder.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isClaimed ? colors.primary20 : Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stopNumber,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.gray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stop.cafeName,
                  style: textTheme.bodyMediumMed.copyWith(
                    color: colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stop.cafeAddress,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.gray,
                  ),
                ),
              ],
            ),
          ),
          if (isClaimed)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(
                Icons.check_circle,
                color: colors.primary60,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}
