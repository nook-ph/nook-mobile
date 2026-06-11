import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stop.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_stop_row.dart';

class CrawlStopsSection extends StatelessWidget {
  final List<CrawlStop> stops;

  const CrawlStopsSection({super.key, required this.stops});

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return const SizedBox.shrink();

    final colors = context.colorScheme;
    final textTheme = context.textTheme;

    final sortedStops = [
      ...stops.where((s) => !s.isClaimed).toList()
        ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder)),
      ...stops.where((s) => s.isClaimed).toList()
        ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stops',
            style: textTheme.titleMedium?.copyWith(
              color: colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Visit in any order \u2014 stamp as you go',
            style: textTheme.bodySmall?.copyWith(
              color: colors.gray,
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < sortedStops.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            CrawlStopRow(
              stop: sortedStops[i],
            ),
          ],
        ],
      ),
    );
  }
}
