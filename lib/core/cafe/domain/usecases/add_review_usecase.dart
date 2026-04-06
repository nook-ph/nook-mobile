import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class AddReviewUseCase {
  final ICafeRepository repository;

  AddReviewUseCase(this.repository);

  Future<Review> call({
    required String cafeId,
    required String userId,
    required int rating,
    required String content,
  }) {
    if (cafeId.trim().isEmpty) {
      throw ArgumentError('Cafe id is required.');
    }

    if (userId.trim().isEmpty) {
      throw ArgumentError('User id is required.');
    }

    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5.');
    }

    return repository.addCafeReview(
      cafeId: cafeId,
      userId: userId,
      rating: rating,
      content: content.trim(),
    );
  }
}
