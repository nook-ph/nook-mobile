import 'package:nook/features/cafe_details/data/datasources/cafe_details_remove_data_source.dart';
import 'package:nook/features/cafe_details/data/models/cafe_details_model.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/domain/repositories/i_cafe_details_repository.dart';

class CafeDetailsRepositoryImpl implements ICafeDetailsRepository {
  final CafeDetailsRemoteDataSource remoteDataSource;

  CafeDetailsRepositoryImpl(this.remoteDataSource);

  @override
  Future<CafeDetailsEntity> getCafeDetails(
    String cafeId, {
    int menuHighlightsLimit = 6,
    int latestReviewsLimit = 3,
  }) async {
    final base = await remoteDataSource.fetchCafeDetailsBase(cafeId);
    final tags = await remoteDataSource.fetchCafeTags(cafeId);
    final highlights = await remoteDataSource.fetchCafeMenuItems(
      cafeId,
      isHighlight: true,
      limit: menuHighlightsLimit,
    );
    final latestReviews = await remoteDataSource.fetchCafeReviews(
      cafeId,
      limit: latestReviewsLimit,
    );

    return CafeDetailsModel(
      id: base.id,
      createdAt: base.createdAt,
      name: base.name,
      description: base.description,
      address: base.address,
      neighborhood: base.neighborhood,
      lat: base.lat,
      lng: base.lng,
      featuredImageUrl: base.featuredImageUrl,
      rating: base.rating,
      reviewCount: base.reviewCount,
      isNew: base.isNew,
      operatingHours: base.operatingHours,
      socialLinks: base.socialLinks,
      menuItems: highlights,
      tags: tags,
      reviews: latestReviews,
    );
  }

  @override
  Future<List<MenuItemEntity>> getCafeMenuHighlights(
    String cafeId, {
    int limit = 20,
    int offset = 0,
  }) {
    return remoteDataSource.fetchCafeMenuItems(
      cafeId,
      isHighlight: true,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<MenuItemEntity>> getCafeMenuItems(
    String cafeId, {
    bool? isHighlight,
    int limit = 100,
    int offset = 0,
  }) {
    return remoteDataSource.fetchCafeMenuItems(
      cafeId,
      isHighlight: isHighlight,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<List<ReviewEntity>> getCafeReviews(
    String cafeId, {
    int limit = 20,
    int offset = 0,
  }) {
    return remoteDataSource.fetchCafeReviews(
      cafeId,
      limit: limit,
      offset: offset,
    );
  }
}