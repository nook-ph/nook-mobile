import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

typedef CafeSummariesResult = ({
  List<CafeSummary> featured,
  List<CafeSummary> recommended,
});

class  GetCafeSummariesUseCase {
  final ICafeRepository repository;

  GetCafeSummariesUseCase(this.repository);

  Future<CafeSummariesResult> call({int page = 0, int limit = 20}) async {
    final results = await Future.wait([
      repository.getCafeSummaries(
        CafeQueryType.featured,
        page: page,
        limit: limit,
      ),
      repository.getCafeSummaries(
        CafeQueryType.recommended,
        page: page,
        limit: limit, 
      ),
    ]);

    final featured = results[0];
    final recommended = results[1];
    await repository.warmCache([...featured, ...recommended]);

    return (featured: featured, recommended: recommended);
  }
}
