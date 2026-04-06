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

  Future<List<Review>> getCafeReviewsById(String cafeId);

  Future<Review> addCafeReview({
    required String cafeId,
    required String userId,
    required int rating,
    required String content,
  });

  Future<List<CafeSummary>> getFavoriteCafes({String? userId});

  Future<void> addFavoriteCafe(String cafeId, {String? userId});

  Future<void> removeFavoriteCafe(String cafeId, {String? userId});

  Future<void> warmCache(List<CafeSummary> summaries);
}
