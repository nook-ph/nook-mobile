import 'package:nook/core/achievements/domain/entities/achievement_definition.dart';

class AchievementDefinitionModel extends AchievementDefinition {
  const AchievementDefinitionModel({
    required super.id,
    required super.slug,
    required super.name,
    super.description,
    required super.category,
    required super.sourceType,
    super.sourceId,
    super.badgeImageUrl,
    super.isLimitedEdition = false,
    super.isHidden = false,
    required super.createdAt,
  });

  factory AchievementDefinitionModel.fromJson(Map<String, dynamic> json) {
    return AchievementDefinitionModel(
      id: _asString(json['id']),
      slug: _asString(json['slug']),
      name: _asString(json['name']),
      description: _asNullableString(json['description']),
      category: _parseCategory(json['category']),
      sourceType: _asString(json['source_type']),
      sourceId: _asNullableString(json['source_id']),
      badgeImageUrl: _asNullableString(json['badge_image_url']),
      isLimitedEdition: _asBool(json['is_limited_edition']),
      isHidden: _asBool(json['is_hidden']),
      createdAt: _asDateTime(json['created_at']),
    );
  }

  static AchievementCategory _parseCategory(dynamic value) {
    return switch (_asString(value)) {
      'drops' => AchievementCategory.drops,
      'social' => AchievementCategory.social,
      'milestones' => AchievementCategory.milestones,
      'hidden' => AchievementCategory.hidden,
      _ => AchievementCategory.crawl,
    };
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static String? _asNullableString(dynamic value) {
    final str = value?.toString().trim();
    return (str == null || str.isEmpty) ? null : str;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final s = value.trim().toLowerCase();
      return s == 'true' || s == '1';
    }
    return false;
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
