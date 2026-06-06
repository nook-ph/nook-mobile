import 'package:nook/features/cafe_details/data/datasources/cafe_details_remote_data_source.dart';
import 'package:nook/features/cafe_details/data/models/cafe_details_model.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/domain/repositories/i_cafe_details_repository.dart';

class CafeDetailsRepositoryImpl implements ICafeDetailsRepository {
  final CafeDetailsRemoteDataSource dataSource;

  CafeDetailsRepositoryImpl(this.dataSource);

  @override
  Future<CafeDetailsEntity> getDetails(String cafeId) async {
    return dataSource.fetchDetails(cafeId);
  }

  @override
  Future<List<MenuItemEntity>> getMenuItems(String cafeId) async {
    final rows = await dataSource.fetchMenuItems(cafeId);
    return rows.map((json) => MenuItemModel.fromJson(json)).toList();
  }

  @override
  Future<List<ReviewEntity>> getReviews(
    String cafeId, {
    String sort = 'recommended',
    int? ratingFilter,
  }) async {
    final rows = await dataSource.fetchReviews(
      cafeId,
      sort: sort,
      ratingFilter: ratingFilter,
    );
    return rows.map((json) => ReviewModel.fromJson(json)).toList();
  }

  @override
  Future<ReviewEntity> addReview({
    required String cafeId,
    required String userId,
    required int rating,
    required String content,
    List<String> imageUrls = const [],
  }) async {
    if (cafeId.trim().isEmpty) {
      throw ArgumentError('Cafe id is required.');
    }
    if (userId.trim().isEmpty) {
      throw ArgumentError('User id is required.');
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5.');
    }

    final json = await dataSource.insertReview(
      cafeId: cafeId,
      userId: userId,
      rating: rating,
      content: content.trim(),
      imageUrls: imageUrls,
    );
    return ReviewModel.fromJson(json);
  }

  @override
  Future<void> toggleHelpfulVote(
    String reviewId,
    String userId,
    bool currentlyVoted,
  ) {
    return dataSource.toggleHelpfulVote(
      reviewId: reviewId,
      userId: userId,
      currentlyVoted: currentlyVoted,
    );
  }
}
