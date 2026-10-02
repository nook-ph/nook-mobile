import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart' as core;
import 'package:nook/core/cafe/domain/use_cases/add_review_usecase.dart';
import 'package:nook/core/upload/data/upload_exception.dart.dart';
import 'package:nook/core/upload/domain/use_cases/upload_use_case.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_event.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_state.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewSubmitBloc extends Bloc<ReviewSubmitEvent, ReviewSubmitState> {
  ReviewSubmitBloc({
    required this.addReviewUseCase,
    required this.uploadReviewImagesUseCase,
  }) : super(const ReviewSubmitInitial()) {
    on<SubmitReviewRequested>(_onSubmitReviewRequested);
  }

  final AddReviewUseCase addReviewUseCase;
  final UploadReviewImagesUseCase uploadReviewImagesUseCase;

  Future<void> _onSubmitReviewRequested(
    SubmitReviewRequested event,
    Emitter<ReviewSubmitState> emit,
  ) async {
    emit(const ReviewSubmitting());

    try {
      final uploadedImages = await uploadReviewImagesUseCase.call(
        cafeId: event.cafeId,
        userId: event.userId,
        images: event.photos,
        accessToken: event.accessToken,
      );

      final inserted = await addReviewUseCase
          .call(
            cafeId: event.cafeId,
            userId: event.userId,
            rating: event.rating,
            content: event.content,
            imageUrls: uploadedImages.map((item) => item.publicUrl).toList(),
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
      imageUrls: review.imageUrls,
      createdAt: review.createdAt,
      updatedAt: review.updatedAt,
      name: review.name,
    );
  }

  static const _signInMessage = 'Please sign in to submit a review.';
  static const _duplicateMessage =
      'You already submitted a review for this cafe.';
  static const _uploadMessage = 'Image upload failed. Please try again.';
  static const _timeoutMessage =
      'Submission timed out. Please check your connection and try again.';

  String _mapErrorMessage(Object error) {
    // The data source wraps what went wrong in a message that names the
    // cafe. Matching on that text would read digits inside the cafe's id
    // ("...401...") as a status code, so only the cause is looked at.
    final cause = error is CafeFetchException ? error.cause : error;

    if (cause is TimeoutException) return _timeoutMessage;
    if (cause is UploadException) return _uploadMessage;
    if (cause is AuthException) return _signInMessage;
    if (cause is PostgrestException) {
      switch (cause.code) {
        case '23505':
          return _duplicateMessage;
        case '42501' || 'PGRST301' || 'PGRST302' || '401' || '403':
          return _signInMessage;
      }
    }

    final message = switch (cause) {
      null => '',
      PostgrestException(:final message) => message,
      ArgumentError(:final message) => '$message',
      _ => cause.toString(),
    }.toLowerCase();

    if (message.contains('rating')) {
      return 'Please select a rating from 1 to 5.';
    }

    if (message.contains('permission') || message.contains('authenticated')) {
      return _signInMessage;
    }

    if (message.contains('duplicate') ||
        message.contains('unique') ||
        message.contains('already submitted')) {
      return _duplicateMessage;
    }

    if (message.contains('upload') ||
        message.contains('presign') ||
        message.contains('s3')) {
      return _uploadMessage;
    }

    if (message.contains('timed out')) return _timeoutMessage;

    return 'Unable to submit your review right now. Please try again.';
  }
}
