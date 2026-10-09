import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class GetSimilarCafesUseCase {
  final ICafeRepository repository;

  GetSimilarCafesUseCase(this.repository);

  Future<List<CafeSummary>> call(String cafeId) {
    return repository.getSimilarCafes(cafeId);
  }
}
