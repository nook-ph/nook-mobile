import 'package:flutter/material.dart';
import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/share_card_footer.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/share_card_stamp_hero.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/share_card_stats.dart';

class CrawlShareCard extends StatelessWidget {
  final CrawlShareCardData data;
  const CrawlShareCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final claimed = data.stops
        .where((s) => s.isClaimed && s.claimedAt != null)
        .toList();
    claimed.sort((a, b) => b.claimedAt!.compareTo(a.claimedAt!));
    final lastClaimed = claimed.isNotEmpty ? claimed.first : null;
    final cafeName = lastClaimed?.cafeName ?? data.crawlTitle;
    final stopNumber = lastClaimed != null
        ? data.stops.indexOf(lastClaimed) + 1
        : 0;

    return SizedBox(
      width: 360,
      height: 640,
      child: Column(
        children: [
          Expanded(
            flex: 55,
            child: ShareCardStampHero(
              cafeName: cafeName,
              stopNumber: stopNumber,
            ),
          ),
          const Divider(color: Color(0xFF2A3E2A), height: 1, thickness: 1),
          Expanded(
            flex: 35,
            child: ShareCardStats(data: data),
          ),
          ShareCardFooter(crawlTitle: data.crawlTitle),
        ],
      ),
    );
  }
}
