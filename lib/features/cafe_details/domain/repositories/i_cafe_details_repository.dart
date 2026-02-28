import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

enum TagCategory { amenities, bestFor, paymentOptions }

extension TagCategoryX on TagCategory {
  String get dbValue => switch (this) {
    TagCategory.amenities => 'amenities',
    TagCategory.bestFor => 'best_for',
    TagCategory.paymentOptions => 'payment_options',
  };
}

abstract class ICafeDetailsRepository {
  Future<CafeDetailsEntity> getCafeDetails(
    String cafeId, {
    int menuHighlightsLimit = 6,
    int latestReviewsLimit = 3,
  });

  Future<List<MenuItemEntity>> getCafeMenuHighlights(
    String cafeId, {
    int limit = 20,
    int offset = 0,
  });

  Future<List<MenuItemEntity>> getCafeMenuItems(
    String cafeId, {
    bool? isHighlight,
    int limit = 100,
    int offset = 0,
  });

  Future<List<ReviewEntity>> getCafeReviews(
    String cafeId, {
    int limit = 20,
    int offset = 0,
  });
}

extension CafeDetailsTagsX on CafeDetailsEntity {
  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll('_', ' ').replaceAll('-', ' ');

  List<TagEntity> tagsFor(TagCategory category) {
    final target = _normalize(category.dbValue);
    return tags.where((t) => _normalize(t.category ?? '') == target).toList();
  }

  List<TagEntity> get amenities => tagsFor(TagCategory.amenities);
  List<TagEntity> get bestFor => tagsFor(TagCategory.bestFor);
  List<TagEntity> get paymentOptions => tagsFor(TagCategory.paymentOptions);  
}


extension CafeDetailsPreviewX on CafeDetailsEntity {
  List<MenuItemEntity> menuHighlights({int max = 6}) =>
      menuItems.where((m) => m.isHighlight).take(max).toList();

  List<ReviewEntity> latestReviews({int max = 3}) => reviews.take(max).toList();
}
