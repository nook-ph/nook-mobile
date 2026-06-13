import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nook/core/cache/custom_cache_manager.dart';
import 'package:nook/features/crawl/domain/entities/crawl_share_card_data.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/share_card_stats.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card/share_card_stamp_hero.dart';

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

    return ColoredBox(
      color: Colors.transparent,
      child: SizedBox(
        width: 360,
        height: 640,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShareCardStampHero(cafeLogoUrl: lastClaimed?.cafeLogoUrl),
              const SizedBox(height: 16),
              ShareCardStats(data: data),
              const SizedBox(height: 0),
              CachedNetworkImage(
                imageUrl:
                    'https://lucerocris.sgp1.cdn.digitaloceanspaces.com/nookLogo.png',
                cacheManager: CustomCacheManager.instance,
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
