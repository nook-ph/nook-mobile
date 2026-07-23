import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class SetCafeRankingUseCase {
  final ICafeRepository repository;

  const SetCafeRankingUseCase(this.repository);

  /// Returns the caller's full refreshed ranking.
  Future<List<CafeRanking>> call({
    required String cafeId,
    required RankBucket bucket,
    required int position,
  }) {
    return repository.setCafeRanking(
      cafeId: cafeId,
      bucket: bucket,
      position: position,
    );
  }
}
