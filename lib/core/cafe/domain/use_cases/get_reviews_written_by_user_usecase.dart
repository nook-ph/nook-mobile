import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class GetReviewsWrittenByUserUseCase {
  final ICafeRepository repository;

  GetReviewsWrittenByUserUseCase(this.repository);

  Future<List<WrittenReview>> call(String userId) {
    return repository.getReviewsWrittenByUser(userId);
  }
}
