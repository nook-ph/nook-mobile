class CrawlTier {
  final String id;
  final String crawlId;
  final String slug;
  final String name;
  final String? description;
  final String? completionCopy;
  final int tierOrder;
  final List<String> requiredTierTags;
  final String? badgeImageUrl;
  final int totalRequired;
  final int totalClaimed;
  final bool isComplete;

  const CrawlTier({
    required this.id,
    required this.crawlId,
    required this.slug,
    required this.name,
    this.description,
    this.completionCopy,
    required this.tierOrder,
    this.requiredTierTags = const [],
    this.badgeImageUrl,
    this.totalRequired = 0,
    this.totalClaimed = 0,
    this.isComplete = false,
  });
}
