import 'package:nook/features/crawl/domain/entities/crawl_tier.dart';

class CrawlTierModel extends CrawlTier {
  const CrawlTierModel({
    required super.id,
    required super.crawlId,
    required super.slug,
    required super.name,
    super.description,
    super.completionCopy,
    required super.tierOrder,
    super.requiredTierTags = const [],
    super.badgeImageUrl,
    super.totalRequired = 0,
    super.totalClaimed = 0,
    super.isComplete = false,
  });

  factory CrawlTierModel.fromJson(Map<String, dynamic> json) {
    return CrawlTierModel(
      id: _asString(json['id']),
      crawlId: _asString(json['crawl_id']),
      slug: _asString(json['slug']),
      name: _asString(json['name']),
      description: _asNullableString(json['description']),
      completionCopy: _asNullableString(json['completion_copy']),
      tierOrder: _asInt(json['tier_order']),
      requiredTierTags: _asStringList(json['required_tier_tags']),
      badgeImageUrl: _asNullableString(json['badge_image_url']),
      totalRequired: _asInt(json['total_required']),
      totalClaimed: _asInt(json['total_claimed']),
      isComplete: _asBool(json['is_complete']),
    );
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static String? _asNullableString(dynamic value) {
    final str = value?.toString().trim();
    return (str == null || str.isEmpty) ? null : str;
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    return const [];
  }
}
