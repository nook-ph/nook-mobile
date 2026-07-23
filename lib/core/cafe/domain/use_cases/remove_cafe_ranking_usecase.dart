import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class RemoveCafeRankingUseCase {
  final ICafeRepository repository;

  const RemoveCafeRankingUseCase(this.repository);

  /// Unranks a cafe without unlogging it.
  Future<void> call(String cafeId) => repository.removeCafeRanking(cafeId);
}
