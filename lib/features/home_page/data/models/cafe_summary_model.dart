import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';

class CafeSummaryModel extends CafeSummaryEntity {
  CafeSummaryModel({
    required super.id,
    required super.name,
    required super.address,
    required super.rating,
    super.featuredImageUrl,
    super.systemBadge,
    super.tags = const [],
  });

  factory CafeSummaryModel.fromJson(Map<String, dynamic> json) {
    List<String> parsedTags = [];
    if (json['cafe_tags'] != null) {
      for (var item in json['cafe_tags']) {
        if (item['is_featured'] == true && item['tags'] != null) {
          parsedTags.add(item['tags']['name']);
        }
      }
    }

    return CafeSummaryModel(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      rating: (json['rating'] as num).toDouble(),
      featuredImageUrl: json['featured_image_url'],
      systemBadge: json['system_badge'],
      tags: parsedTags,
    );
  }
}
