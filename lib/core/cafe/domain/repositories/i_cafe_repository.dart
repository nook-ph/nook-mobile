import 'package:nook/core/cafe/domain/entities/cafe_bundle.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/utils/geo.dart';

@Deprecated('Use CafeQuery with getCafes for home/feed flows.')
enum CafeQueryType { featured, recommended, nearby }

abstract class ICafeRepository {
  Future<List<CafeSummary>> getCafes(CafeQuery query);

  /// Cafes within [radiusMeters] of a point (map, zoomed in).
  Future<List<CafeSummary>> getCafesNearPoint({
    required double lat,
    required double lng,
    required double radiusMeters,
    String? query,
    List<String> tags,
    String? sort,
  });

  /// Cafes inside the visible [bounds] (map, zoomed out). [lat]/[lng] feed
  /// distance-based sorting when [sort] needs a reference point.
  Future<List<CafeSummary>> getCafesInViewport({
    required MapBounds bounds,
    String? query,
    List<String> tags,
    String? sort,
    double? lat,
    double? lng,
  });

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

  Future<List<WrittenReview>> getReviewsWrittenByUser(String userId);

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

  Future<void> deleteReview(String reviewId);

  /// Files a user report against a review (lands in the moderation queue).
  Future<void> reportReview({
    required String reviewId,
    required String cafeId,
    required String reporterId,
    required String reasonCode,
    String? description,
  });

  // lists
  Future<String> getDefaultListId();
  Future<List<CafeList>> getUserLists();
  Future<List<CafeSummary>> getListCafes(String listId);
  Future<Set<String>> getCafeListMemberships(
    String cafeId,
    List<String> listIds,
  );
  Future<bool> isCafeInList(String listId, String cafeId);

  /// True if [cafeId] appears in any list the user owns (see [getUserLists]).
  Future<bool> isCafeSavedToAnyUserList(String cafeId);

  Future<void> addCafeToList(String listId, String cafeId);
  Future<void> removeCafeFromList(String listId, String cafeId);

  /// Removes [cafeId] from every list the user owns (same membership scope as [getUserLists]).
  Future<void> removeCafeFromAllUserLists(String cafeId);

  Future<String> createList({
    required String name,
    String? description,
    required bool isPublic,
  });
  Future<void> deleteList(String listId);

  // Replaced renameList with updateList
  Future<void> updateList(
    String listId, {
    required String name,
    String? description,
    required bool isPublic,
  });

  Future<void> warmCache(List<CafeSummary> summaries);
}
