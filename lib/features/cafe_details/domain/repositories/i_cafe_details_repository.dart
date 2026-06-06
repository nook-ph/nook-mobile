import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

abstract class ICafeDetailsRepository {
  Future<CafeDetailsEntity> getDetails(String cafeId);

  Future<List<MenuItemEntity>> getMenuItems(String cafeId);

  Future<List<ReviewEntity>> getReviews(
    String cafeId, {
    String sort = 'recommended',
    int? ratingFilter,
  });

  Future<ReviewEntity> addReview({
    required String cafeId,
    required String userId,
    required int rating,
    required String content,
    List<String> imageUrls = const [],
  });

  Future<void> toggleHelpfulVote(
    String reviewId,
    String userId,
    bool currentlyVoted,
  );
}
