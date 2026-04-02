import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

class GetCafeDetailsParams {
  final String cafeId;
  final int menuHighlightsLimit;
  final int latestReviewsLimit;
  final int allMenuLimit;
  final int allReviewsLimit;

  GetCafeDetailsParams({
    required this.cafeId,
    this.menuHighlightsLimit = 6,
    this.latestReviewsLimit = 5,
    this.allMenuLimit = 50,
    this.allReviewsLimit = 50,
  });
}

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
