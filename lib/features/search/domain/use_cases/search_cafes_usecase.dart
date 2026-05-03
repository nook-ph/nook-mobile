import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class SearchCafesUseCase {
  final ICafeRepository repository;

  SearchCafesUseCase(this.repository);

  Future<List<CafeSummary>> call(CafeQuery query) async {
    return repository.getCafes(query);
  }
}
