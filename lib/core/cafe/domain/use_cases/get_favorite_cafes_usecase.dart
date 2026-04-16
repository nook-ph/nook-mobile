import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class GetFavoriteCafesUseCase {
  final ICafeRepository repository;

  GetFavoriteCafesUseCase(this.repository);

  Future<List<CafeSummary>> call({String? userId}) {
    return repository.getFavoriteCafes(userId: userId);
  }
}
