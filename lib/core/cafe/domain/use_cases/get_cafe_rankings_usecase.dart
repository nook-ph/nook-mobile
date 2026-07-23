import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class GetCafeRankingsUseCase {
  final ICafeRepository repository;

  const GetCafeRankingsUseCase(this.repository);

  /// The caller's whole ranking, best first within each bucket.
  Future<List<CafeRanking>> call() => repository.getCafeRankings();
}
