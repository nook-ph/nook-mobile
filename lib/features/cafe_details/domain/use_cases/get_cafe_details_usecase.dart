import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/domain/repositories/i_cafe_details_repository.dart';

class GetCafeDetailsParams {
  final String cafeId;
  final int menuHighlightsLimit;
  final int latestReviewsLimit;
  final int allMenuLimit;
  final int allReviewsLimit;

  GetCafeDetailsParams({
    required this.cafeId,
    this.menuHighlightsLimit = 3,
    this.latestReviewsLimit = 5,
    this.allMenuLimit = 50,
    this.allReviewsLimit = 50,
  });
}

class CafeDetailsResult {
  final CafeDetailsEntity cafeDetails;
  final List<MenuItemEntity> menuHighlights;
  final List<MenuItemEntity> allMenuItems;
  final List<ReviewEntity> latestReviews;
  final List<ReviewEntity> allReviews;

  CafeDetailsResult({
    required this.cafeDetails,
    required this.menuHighlights,
    required this.allMenuItems,
    required this.latestReviews,
    required this.allReviews,
  });
}

class GetCafeDetailsUseCase {
  final ICafeDetailsRepository repository;

  GetCafeDetailsUseCase(this.repository);

  Future<CafeDetailsResult> call(GetCafeDetailsParams params) async {

    final detailsFuture = repository.getCafeDetails(
      params.cafeId,
      menuHighlightsLimit: params.menuHighlightsLimit,
      latestReviewsLimit: params.latestReviewsLimit,
    );

    final allMenuFuture = repository.getCafeMenuItems(
      params.cafeId,
      limit: params.allMenuLimit,
      offset: 0,
    );

    final allReviewsFuture = repository.getCafeReviews(
      params.cafeId,
      limit: params.allReviewsLimit,
      offset: 0,
    );

    final details = await detailsFuture;
    final allMenuItems = await allMenuFuture;
    final allReviews = await allReviewsFuture;

    return CafeDetailsResult(
      cafeDetails: details,
      menuHighlights: details.menuHighlights(max: params.menuHighlightsLimit),
      allMenuItems: allMenuItems,
      latestReviews: details.latestReviews(max: params.latestReviewsLimit),
      allReviews: allReviews,
    );
  }
}
