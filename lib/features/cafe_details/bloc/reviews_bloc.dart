import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart' as core;
import 'package:nook/core/cafe/domain/use_cases/get_cafe_reviews_usecase.dart';
import 'package:nook/features/cafe_details/bloc/reviews_event.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

class ReviewsBloc extends Bloc<ReviewsEvent, ReviewsState> {
  ReviewsBloc({required this.getCafeReviewsUseCase})
    : super(const ReviewsInitial()) {
    on<LoadReviewsRequested>(_onLoadReviewsRequested);
  }

  final GetCafeReviewsUseCase getCafeReviewsUseCase;

  /// Loads run concurrently and the state does not say which filter it is
  /// for, so only the newest request may land: a slow filtered response
  /// arriving after the filter was cleared is dropped.
  int _latestRequest = 0;

  Future<void> _onLoadReviewsRequested(
    LoadReviewsRequested event,
    Emitter<ReviewsState> emit,
  ) async {
    final request = ++_latestRequest;
    emit(const ReviewsLoading());

    try {
      final reviews = await getCafeReviewsUseCase.call(
        event.cafeId,
        sort: event.sort,
        ratingFilter: event.ratingFilter,
      );
      if (request != _latestRequest) return;
      emit(
        ReviewsLoaded(
          cafeId: event.cafeId,
          reviews: reviews.map(_toFeatureReview).toList(),
        ),
      );
    } catch (e) {
      if (request != _latestRequest) return;
      emit(ReviewsError(e.toString(), error: e));
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
      helpfulCount: review.helpfulCount,
      hasVoted: review.hasVoted,
    );
  }
}
