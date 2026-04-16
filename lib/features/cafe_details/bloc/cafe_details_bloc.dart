import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_bundle.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart' as core;
import 'package:nook/core/cafe/domain/use_cases/get_cafe_details_usecase.dart'
    as core_usecase;
import 'package:nook/features/cafe_details/bloc/cafe_details_event.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_states.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';

class CafeDetailsBloc extends Bloc<CafeDetailsEvent, CafeDetailsState> {
  final core_usecase.GetCafeDetailsUseCase getCafeDetailsUseCase;

  CafeDetailsBloc({required this.getCafeDetailsUseCase})
    : super(const CafeDetailsInitial()) {
    on<LoadCafeDetailsRequested>(_onLoadCafeDetailsRequested);
  }

  Future<void> _onLoadCafeDetailsRequested(
    LoadCafeDetailsRequested event,
    Emitter<CafeDetailsState> emit,
  ) async {
    emit(const CafeDetailsLoading());

    try {
      final bundle = await getCafeDetailsUseCase.call(event.cafeId);
      final result = _toFeatureResult(
        bundle,
        menuHighlightsLimit: event.menuHighlightsLimit,
        latestReviewsLimit: event.latestReviewsLimit,
      );

      emit(CafeDetailsLoaded(result));
    } catch (e) {
      emit(CafeDetailsError(e.toString()));
    }
  }

  CafeDetailsResult _toFeatureResult(
    CafeBundle bundle, {
    required int menuHighlightsLimit,
    required int latestReviewsLimit,
  }) {
    final menuItems = (bundle.menu ?? const <core.MenuItem>[])
        .map(
          (item) => MenuItemEntity(
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
        .toList();

    final reviews = (bundle.reviews ?? const <core.Review>[])
        .map(
          (item) => ReviewEntity(
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
        .toList();

    final details = CafeDetailsEntity(
      id: bundle.details.id,
      createdAt: bundle.details.createdAt,
      name: bundle.details.name,
      description: bundle.details.description,
      address: bundle.details.address,
      neighborhood: bundle.details.neighborhood,
      lat: bundle.details.lat,
      lng: bundle.details.lng,
      featuredImageUrl: bundle.details.coverImage,
      photos: bundle.details.photos,
      rating: bundle.details.rating,
      reviewCount: bundle.details.reviewCount,
      isNew: bundle.details.isNew,
      operatingHours: bundle.details.operatingHours,
      socialLinks: bundle.details.socialLinks,
      menuItems: menuItems,
      tags: bundle.details.tags
          .map(
            (tag) => TagEntity(
              id: tag.id,
              name: tag.name,
              category: tag.category,
              iconName: tag.iconName,
              createdAt: tag.createdAt,
              isFeatured: tag.isFeatured,
            ),
          )
          .toList(),
      reviews: reviews,
    );

    return CafeDetailsResult(
      cafeDetails: details,
      menuHighlights: menuItems
          .where((item) => item.isHighlight)
          .take(menuHighlightsLimit)
          .toList(),
      allMenuItems: menuItems,
      latestReviews: reviews.take(latestReviewsLimit).toList(),
      allReviews: reviews,
    );
  }
}
