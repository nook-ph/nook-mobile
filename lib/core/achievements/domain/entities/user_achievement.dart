import 'package:nook/core/achievements/domain/entities/achievement_definition.dart';

class UserAchievement {
  final String id;
  final String userId;
  final AchievementDefinition definition;
  final DateTime earnedAt;
  final String sourceType;
  final String? sourceRefId;
  final Map<String, dynamic>? metadata;
  final bool isVisible;

  const UserAchievement({
    required this.id,
    required this.userId,
    required this.definition,
    required this.earnedAt,
    required this.sourceType,
    this.sourceRefId,
    this.metadata,
    this.isVisible = true,
  });
}
