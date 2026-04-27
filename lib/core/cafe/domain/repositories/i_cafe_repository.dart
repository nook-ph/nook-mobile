import 'package:nook/core/cafe/domain/entities/cafe_bundle.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/lists/domain/entities/cafe_list.dart';

@Deprecated('Use CafeQuery with getCafes for home/feed flows.')
enum CafeQueryType { featured, recommended, nearby }

abstract class ICafeRepository {
  Future<List<CafeSummary>> getCafes(CafeQuery query);

  // @Deprecated('Use getCafes(CafeQuery) for home/feed flows.')
  // Future<List<CafeSummary>> getCafeSummaries(
  //   CafeQueryType type, {
  //   int page = 0,
  //   int limit = 20,
  // });

  Future<CafeDetails> getCafeDetailsById(String cafeId);

  Future<CafeBundle> getCafeBundleById(
    String cafeId, {
    bool includeMenu = true,
    bool includeReviews = true,
  });

  Future<List<Review>> getCafeReviewsById(
    String cafeId, {
    String sort = 'recommended',
    int? ratingFilter,
  });

  Future<void> toggleHelpfulVote(
    String reviewId,
    String userId,
    bool currentlyVoted,
  );

  Future<Review> addCafeReview({
    required String cafeId,
    required String userId,
    required int rating,
    required String content,
    List<String> imageUrls = const [],
  });

  @Deprecated('Use fetchListCafes with the default list id.')
  Future<List<CafeSummary>> getFavoriteCafes({String? userId});
  @Deprecated('Use addCafeToList with the default list id.')
  Future<void> addFavoriteCafe(String cafeId, {String? userId});
  @Deprecated('Use removeCafeFromList with the default list id.')
  Future<void> removeFavoriteCafe(String cafeId, {String? userId});

  // lists

  Future<String> getDefaultListId();
  Future<List<CafeList>> getUserLists();
  Future<List<CafeSummary>> getListCafes(String listId);
  Future<void> addCafeToList(String listId, String cafeId);
  Future<void> removeCafeFromList(String listId, String cafeId);
  Future<String> createList({required String name, String? description});
  Future<void> deleteList(String listId);

  Future<void> warmCache(List<CafeSummary> summaries);
}
