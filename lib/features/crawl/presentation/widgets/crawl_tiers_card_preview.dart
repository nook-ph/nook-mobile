import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:nook/features/crawl/domain/entities/crawl_tier.dart';
import 'package:nook/features/crawl/presentation/widgets/crawl_tiers_card.dart';

List<CrawlTier> _allStates() {
  return [
    CrawlTier(
      id: 'tier-1',
      crawlId: 'crawl-1',
      slug: 'explorer',
      name: 'Explorer',
      tierOrder: 1,
      totalRequired: 5,
      totalClaimed: 5,
      isComplete: true,
    ),
    CrawlTier(
      id: 'tier-2',
      crawlId: 'crawl-1',
      slug: 'adventurer',
      name: 'Adventurer',
      tierOrder: 2,
      totalRequired: 10,
      totalClaimed: 4,
      isComplete: false,
    ),
    CrawlTier(
      id: 'tier-3',
      crawlId: 'crawl-1',
      slug: 'trailblazer',
      name: 'Trailblazer',
      tierOrder: 3,
      totalRequired: 15,
      totalClaimed: 0,
      isComplete: false,
    ),
  ];
}

Widget _buildPreview({required List<CrawlTier> tiers}) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: CrawlTiersCard(tiers: tiers),
      ),
    ),
    theme: ThemeData.light(),
  );
}

@Preview(name: 'All Three States', group: 'Crawl Tiers Card')
Widget allThreeStates() {
  return _buildPreview(tiers: _allStates());
}
