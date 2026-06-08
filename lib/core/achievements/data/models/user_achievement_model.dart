import 'package:nook/core/achievements/data/models/achievement_definition_model.dart';
import 'package:nook/core/achievements/domain/entities/user_achievement.dart';

class UserAchievementModel extends UserAchievement {
  const UserAchievementModel({
    required super.id,
    required super.userId,
    required super.definition,
    required super.earnedAt,
    required super.sourceType,
    super.sourceRefId,
    super.metadata,
    super.isVisible = true,
  });

  factory UserAchievementModel.fromJson(Map<String, dynamic> json) {
    final definitionJson = json['achievement_definitions'] ??
        json['achievement_definition'] ??
        json['definition'];
    final AchievementDefinitionModel definition = definitionJson is Map
        ? AchievementDefinitionModel.fromJson(
            Map<String, dynamic>.from(definitionJson),
          )
        : (throw const FormatException('Missing achievement definition'));

    return UserAchievementModel(
      id: _asString(json['id']),
      userId: _asString(json['user_id']),
      definition: definition,
      earnedAt: _asDateTime(json['earned_at']),
      sourceType: _asString(json['source_type']),
      sourceRefId: _asNullableString(json['source_ref_id']),
      metadata: _asNullableMap(json['metadata']),
      isVisible: _asBool(json['is_visible']),
    );
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

  static Map<String, dynamic>? _asNullableMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }
}
