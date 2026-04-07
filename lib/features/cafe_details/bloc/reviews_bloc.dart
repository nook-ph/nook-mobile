import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart' as core;
import 'package:nook/core/cafe/domain/usecases/get_cafe_reviews_usecase.dart';
import 'package:nook/features/cafe_details/bloc/reviews_event.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

class ReviewsBloc extends Bloc<ReviewsEvent, ReviewsState> {
  ReviewsBloc({required this.getCafeReviewsUseCase})
    : super(const ReviewsInitial()) {
    on<LoadReviewsRequested>(_onLoadReviewsRequested);
  }

  final GetCafeReviewsUseCase getCafeReviewsUseCase;

  Future<void> _onLoadReviewsRequested(
    LoadReviewsRequested event,
    Emitter<ReviewsState> emit,
  ) async {
    emit(const ReviewsLoading());

    try {
      final reviews = await getCafeReviewsUseCase.call(event.cafeId);
      emit(
        ReviewsLoaded(
          cafeId: event.cafeId,
          reviews: reviews.map(_toFeatureReview).toList(),
        ),
      );
    } catch (e) {
      emit(ReviewsError(e.toString()));
    }
  }

  ReviewEntity _toFeatureReview(core.Review review) {
    return ReviewEntity(
      id: review.id,
      cafeId: review.cafeId,
      userId: review.userId,
      rating: review.rating,
      content: review.content,
      imageUrls: review.imageUrls,
      createdAt: review.createdAt,
      updatedAt: review.updatedAt,
      name: review.name,
    );
  }
}
