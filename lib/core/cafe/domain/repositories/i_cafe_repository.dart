import 'package:nook/core/cafe/domain/entities/cafe_bundle.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

enum CafeQueryType { featured, recommended, nearby }

abstract class ICafeRepository {
  Future<List<CafeSummary>> getCafeSummaries(
    CafeQueryType type, {
    int page = 0,
    int limit = 20,
  });

  Future<CafeDetails> getCafeDetailsById(String cafeId);

  Future<CafeBundle> getCafeBundleById(
    String cafeId, {
    bool includeMenu = true,
    bool includeReviews = true,
  });

  Future<void> warmCache(List<CafeSummary> summaries);
}
