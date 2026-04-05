import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart' as core;
import 'package:nook/core/cafe/domain/usecases/add_review_usecase.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_event.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_state.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

class ReviewSubmitBloc extends Bloc<ReviewSubmitEvent, ReviewSubmitState> {
  ReviewSubmitBloc({required this.addReviewUseCase})
    : super(const ReviewSubmitInitial()) {
    on<SubmitReviewRequested>(_onSubmitReviewRequested);
  }

  final AddReviewUseCase addReviewUseCase;

  Future<void> _onSubmitReviewRequested(
    SubmitReviewRequested event,
    Emitter<ReviewSubmitState> emit,
  ) async {
    emit(const ReviewSubmitting());

    try {
      final inserted = await addReviewUseCase
          .call(
            cafeId: event.cafeId,
            userId: event.userId,
            rating: event.rating,
            content: event.content,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw TimeoutException('Review submission timed out.'),
          );

      emit(ReviewSubmitSuccess(review: _toFeatureReview(inserted)));
    } catch (e) {
      emit(ReviewSubmitError(_mapErrorMessage(e)));
    }
  }

  ReviewEntity _toFeatureReview(core.Review review) {
    return ReviewEntity(
      id: review.id,
      cafeId: review.cafeId,
      userId: review.userId,
      rating: review.rating,
      content: review.content,
      createdAt: review.createdAt,
      updatedAt: review.updatedAt,
      name: review.name,
    );
  }

  String _mapErrorMessage(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('rating')) {
      return 'Please select a rating from 1 to 5.';
    }

    if (message.contains('permission') ||
        message.contains('authenticated') ||
        message.contains('401')) {
      return 'Please sign in to submit a review.';
    }

    if (message.contains('duplicate') ||
        message.contains('unique') ||
        message.contains('already submitted')) {
      return 'You already submitted a review for this cafe.';
    }

    if (error is TimeoutException || message.contains('timed out')) {
      return 'Submission timed out. Please check your connection and try again.';
    }

    return 'Unable to submit your review right now. Please try again.';
  }
}
