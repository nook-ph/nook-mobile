import 'package:nook/features/crawl/domain/entities/crawl.dart';

class CrawlModel extends Crawl {
  const CrawlModel({
    required super.id,
    required super.title,
    super.description,
    required super.slug,
    required super.startsAt,
    required super.endsAt,
    required super.status,
    super.coverImageUrl,
    super.isFeatured = false,
    required super.city,
    super.totalStops = 0,
    super.stampTemplateUrl,
  });

  factory CrawlModel.fromJson(Map<String, dynamic> json) {
    return CrawlModel(
      id: _asString(json['id']),
      title: _asString(json['title']),
      description: _asNullableString(json['description']),
      slug: _asString(json['slug']),
      startsAt: _asDateTime(json['starts_at']),
      endsAt: _asDateTime(json['ends_at']),
      status: _parseStatus(json['status']),
      coverImageUrl: _asNullableString(json['cover_image_url']),
      isFeatured: _asBool(json['is_featured']),
      city: _asString(json['city']),
      totalStops: _asInt(json['total_stops']),
      stampTemplateUrl: _asNullableString(json['stamp_template_url']),
    );
  }

  static CrawlStatus _parseStatus(dynamic value) {
    return switch (_asString(value)) {
      'active' => CrawlStatus.active,
      'completed' => CrawlStatus.completed,
      'cancelled' => CrawlStatus.cancelled,
      _ => CrawlStatus.draft,
    };
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

  static DateTime _asDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
