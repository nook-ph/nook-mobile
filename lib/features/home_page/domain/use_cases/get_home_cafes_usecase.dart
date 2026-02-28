import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';
import 'package:nook/features/home_page/domain/repositories/i_home_repository.dart';

class HomeCafesResult {
  final List<CafeSummaryEntity> featured;
  final List<CafeSummaryEntity> recommended;

  HomeCafesResult({required this.featured, required this.recommended});
}

class GetHomeCafesUseCase {
  final IHomeRepository repository;

  GetHomeCafesUseCase(this.repository);

  Future<HomeCafesResult> call() async {
    final results = await Future.wait([
      repository.getFeaturedCafes(),
      repository.getRecommendedCafes(),                             
    ]);

    return HomeCafesResult(featured: results[0], recommended: results[1]);
  }
}
