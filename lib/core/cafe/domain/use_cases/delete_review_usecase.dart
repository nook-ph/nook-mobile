import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class DeleteReviewUseCase {
  final ICafeRepository repository;

  DeleteReviewUseCase(this.repository);

  Future<void> call(String reviewId) {
    if (reviewId.trim().isEmpty) {
      throw ArgumentError('Review id is required.');
    }
    return repository.deleteReview(reviewId);
  }
}
