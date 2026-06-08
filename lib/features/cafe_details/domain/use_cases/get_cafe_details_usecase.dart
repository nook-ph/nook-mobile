import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

class CafeDetailsResult {
  final CafeDetailsEntity cafeDetails;
  final List<MenuItemEntity> menuHighlights;
  final List<MenuItemEntity> allMenuItems;
  final List<ReviewEntity> latestReviews;
  final List<ReviewEntity> allReviews;

  CafeDetailsResult({
    required this.cafeDetails,
    required this.menuHighlights,
    required this.allMenuItems,
    required this.latestReviews,
    required this.allReviews,
  });
}
