enum AchievementCategory { crawl, drops, social, milestones, hidden }

class AchievementDefinition {
  final String id;
  final String slug;
  final String name;
  final String? description;
  final AchievementCategory category;
  final String sourceType;
  final String? sourceId;
  final String? badgeImageUrl;
  final bool isLimitedEdition;
  final bool isHidden;
  final DateTime createdAt;

  const AchievementDefinition({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    required this.category,
    required this.sourceType,
    this.sourceId,
    this.badgeImageUrl,
    this.isLimitedEdition = false,
    this.isHidden = false,
    required this.createdAt,
  });
}
