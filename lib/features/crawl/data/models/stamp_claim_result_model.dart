import 'package:nook/features/crawl/data/models/crawl_stamp_model.dart';
import 'package:nook/features/crawl/domain/entities/stamp_claim_result.dart';

class StampClaimResultModel extends StampClaimResult {
  const StampClaimResultModel({
    required super.stamp,
    super.totalStamps = 0,
    super.tierCompletion,
  });

  factory StampClaimResultModel.fromJson(Map<String, dynamic> json) {
    final stampJson = json['stamp'];
    final stamp = stampJson is Map
        ? CrawlStampModel.fromJson(Map<String, dynamic>.from(stampJson))
        : null;

    final tierJson = json['tier_completion'];

    return StampClaimResultModel(
      stamp: stamp ??
          (throw const FormatException('Missing stamp in claim result')),
      totalStamps: _asInt(json['total_stamps']),
      tierCompletion: tierJson is Map
          ? TierCompletionResultModel.fromJson(
              Map<String, dynamic>.from(tierJson),
            )
          : null,
    );
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }
}

class TierCompletionResultModel extends TierCompletionResult {
  const TierCompletionResultModel({
    required super.tierId,
    required super.tierSlug,
    required super.tierName,
    super.completionCopy,
    required super.achievementId,
    super.badgeImageUrl,
    required super.earnedAt,
  });

  factory TierCompletionResultModel.fromJson(Map<String, dynamic> json) {
    return TierCompletionResultModel(
      tierId: _asString(json['tier_id']),
      tierSlug: _asString(json['tier_slug']),
      tierName: _asString(json['tier_name']),
      completionCopy: _asNullableString(json['completion_copy']),
      achievementId: _asString(json['achievement_id']),
      badgeImageUrl: _asNullableString(json['badge_image_url']),
      earnedAt: _asDateTime(json['earned_at']),
    );
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static String? _asNullableString(dynamic value) {
    final str = value?.toString().trim();
    return (str == null || str.isEmpty) ? null : str;
  }

  static DateTime _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
