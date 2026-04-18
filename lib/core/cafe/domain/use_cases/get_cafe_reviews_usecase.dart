import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class GetCafeReviewsUseCase {
  final ICafeRepository repository;

  GetCafeReviewsUseCase(this.repository);

  Future<List<Review>> call(
    String cafeId, {
    String sort = 'recommended',
    int? ratingFilter,
  }) {
    return repository.getCafeReviewsById(
      cafeId,
      sort: sort,
      ratingFilter: ratingFilter,
    );
  }
}
