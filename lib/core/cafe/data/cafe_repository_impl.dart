import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/cafe/data/cafe_store.dart';
import 'package:nook/core/cafe/domain/entities/cafe_bundle.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CafeRepositoryImpl implements ICafeRepository {
  final CafeRemoteDataSource remoteDataSource;
  final CafeStore store;

  CafeRepositoryImpl(this.remoteDataSource, this.store);

  @override
  Future<List<CafeSummary>> getCafes(CafeQuery query) async {
    return remoteDataSource.fetchCafes(query: query);
  }

  @override
  @Deprecated('Use getCafes(CafeQuery) for home/feed flows.')
  Future<List<CafeSummary>> getCafeSummaries(
    CafeQueryType type, {
    int page = 0,
    int limit = 20,
  }) async {
    return getCafes(
      CafeQuery(sort: _queryTypeToSort(type), page: page, limit: limit),
    );
  }

  @override
  Future<CafeDetails> getCafeDetailsById(String cafeId) async {
    final details = await remoteDataSource.fetchDetailsById(cafeId);
    return _mapDetails(details);
  }

  @override
  Future<CafeBundle> getCafeBundleById(
    String cafeId, {
    bool includeMenu = true,
    bool includeReviews = true,
  }) async {
    if (!store.isStale(cafeId)) {
      final cached = store.get(cafeId);
      if (cached != null) {
        final isSummarySeed =
            cached.details.createdAt.millisecondsSinceEpoch == 0;
        final missingMenu = includeMenu && cached.menu == null;
        final missingReviews = includeReviews && cached.reviews == null;
        final needsRefresh = isSummarySeed || missingMenu || missingReviews;

        if (!needsRefresh) {
          return cached;
        }
      }
    }

    final bundleModel = await remoteDataSource.fetchBundleById(
      cafeId,
      includeMenu: includeMenu,
      includeReviews: includeReviews,
    );

    final mapped = CafeBundle(
      details: _mapDetails(bundleModel.details),
      menu: bundleModel.menu
          ?.map(
            (item) => MenuItem(
              id: item.id,
              cafeId: item.cafeId,
              name: item.name,
              price: item.price,
              imageUrl: item.imageUrl,
              isHighlight: item.isHighlight,
              categoryId: item.categoryId,
              categoryName: item.categoryName,
            ),
          )
          .toList(),
      reviews: bundleModel.reviews
          ?.map(
            (item) => Review(
              id: item.id,
              cafeId: item.cafeId,
              userId: item.userId,
              rating: item.rating,
              content: item.content,
              imageUrls: item.imageUrls,
              createdAt: item.createdAt,
              updatedAt: item.updatedAt,
              name: item.name,
            ),
          )
          .toList(),
    );

    store.set(cafeId, mapped);
    return mapped;
  }

  @override
  Future<List<Review>> getCafeReviewsById(String cafeId) async {
    final reviews = await remoteDataSource.fetchReviewsByCafeId(cafeId);

    return reviews
        .map(
          (item) => Review(
            id: item.id,
            cafeId: item.cafeId,
            userId: item.userId,
            rating: item.rating,
            content: item.content,
            imageUrls: item.imageUrls,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            name: item.name,
            helpfulCount: item.helpfulCount,
            hasVoted: item.hasVoted,
          ),
        )
        .toList();
  }

  @override
  Future<void> toggleHelpfulVote(
    String reviewId,
    String userId,
    bool currentlyVoted,
  ) {
    return remoteDataSource.toggleHelpfulVote(
      reviewId: reviewId,
      userId: userId,
      currentlyVoted: currentlyVoted,
    );
  }

  @override
  Future<Review> addCafeReview({
    required String cafeId,
    required String userId,
    required int rating,
    required String content,
    List<String> imageUrls = const [],
  }) async {
    final inserted = await remoteDataSource.insertReview(
      cafeId: cafeId,
      userId: userId,
      rating: rating,
      content: content,
      imageUrls: imageUrls,
    );

    return Review(
      id: inserted.id,
      cafeId: inserted.cafeId,
      userId: inserted.userId,
      rating: inserted.rating,
      content: inserted.content,
      imageUrls: inserted.imageUrls,
      createdAt: inserted.createdAt,
      updatedAt: inserted.updatedAt,
      name: inserted.name,
    );
  }

  @override
  Future<List<CafeSummary>> getFavoriteCafes({String? userId}) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      return [];
    }

    final favorites = await remoteDataSource.fetchFavorites(userId: userId);

    return favorites;
  }

  @override
  Future<void> addFavoriteCafe(String cafeId, {String? userId}) {
    return remoteDataSource.addFavorite(cafeId, userId: userId);
  }

  @override
  Future<void> removeFavoriteCafe(String cafeId, {String? userId}) {
    return remoteDataSource.removeFavorite(cafeId, userId: userId);
  }

  @override
  Future<void> warmCache(List<CafeSummary> summaries) async {
    for (final summary in summaries) {
      final existing = store.get(summary.id);
      if (existing != null) {
        final updated = existing.copyWith(
          details: existing.details.copyWithSummary(summary),
        );
        store.set(summary.id, updated);
        continue;
      }

      final seededDetails = CafeDetails(
        id: summary.id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        name: summary.name,
        description: '',
        address: '',
        neighborhood: '',
        lat: 0,
        lng: 0,
        coverImage: summary.coverImage,
        photos: summary.coverImage != null ? [summary.coverImage!] : const [],
        rating: summary.rating,
        reviewCount: 0,
        isNew: false,
        operatingHours: const {},
        socialLinks: const {},
        tags: summary.tags.map((name) => Tag(id: name, name: name)).toList(),
      );

      store.set(
        summary.id,
        CafeBundle(details: seededDetails, menu: null, reviews: null),
      );
    }
  }

  String _queryTypeToSort(CafeQueryType type) {
    switch (type) {
      case CafeQueryType.featured:
        return 'trending';
      case CafeQueryType.recommended:
        return 'top_rated';
      case CafeQueryType.nearby:
        return 'nearby';
    }
  }

  CafeDetails _mapDetails(dynamic details) {
    final mappedTags = (details.tags as Iterable)
        .map<Tag>(
          (tag) => Tag(
            id: (tag as dynamic).id,
            name: tag.name,
            category: tag.category,
            iconName: tag.iconName,
            createdAt: tag.createdAt,
            isFeatured: tag.isFeatured,
          ),
        )
        .toList(growable: false);

    return CafeDetails(
      id: details.id,
      createdAt: details.createdAt,
      name: details.name,
      description: details.description,
      address: details.address,
      neighborhood: details.neighborhood,
      lat: details.lat,
      lng: details.lng,
      coverImage: details.featuredImageUrl,
      photos: details.photos,
      rating: details.rating,
      reviewCount: details.reviewCount,
      isNew: details.isNew,
      operatingHours: details.operatingHours,
      socialLinks: details.socialLinks,
      tags: mappedTags,
    );
  }
}

extension on CafeDetails {
  CafeDetails copyWithSummary(CafeSummary summary) {
    return CafeDetails(
      id: id,
      createdAt: createdAt,
      name: summary.name,
      description: description,
      address: address,
      neighborhood: neighborhood,
      lat: lat,
      lng: lng,
      coverImage: summary.coverImage,
      photos: photos,
      rating: summary.rating,
      reviewCount: reviewCount,
      isNew: isNew,
      operatingHours: operatingHours,
      socialLinks: socialLinks,
      tags: summary.tags
          .map(
            (name) => Tag(id: name, name: name, isFeatured: summary.isFeatured),
          )
          .toList(),
    );
  }
}
