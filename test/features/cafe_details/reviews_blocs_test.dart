import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/add_review_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_reviews_usecase.dart';
import 'package:nook/core/upload/data/upload_exception.dart.dart';
import 'package:nook/core/upload/domain/entities/uploaded_review_image.dart';
import 'package:nook/core/upload/domain/repositories/i_review_image_upload_repository.dart';
import 'package:nook/core/upload/domain/use_cases/upload_use_case.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_bloc.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_event.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_state.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_event.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Review _review(String id, int rating) => Review(
  id: id,
  cafeId: 'cafe',
  userId: 'user-$id',
  rating: rating,
  content: 'Review $id',
  createdAt: DateTime(2026, 5, 23),
  updatedAt: DateTime(2026, 5, 23),
);

/// Each load waits on its own completer, so a test decides the order the
/// responses come back in.
class _GatedReviewsRepository implements ICafeRepository {
  final gates = <int?, Completer<List<Review>>>{};

  @override
  Future<List<Review>> getCafeReviewsById(
    String cafeId, {
    String sort = 'recommended',
    int? ratingFilter,
  }) => (gates[ratingFilter] = Completer<List<Review>>()).future;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _SubmitRepository implements ICafeRepository, IUploadRepository {
  Object? insertError;
  Object? uploadError;

  @override
  Future<Review> addCafeReview({
    required String cafeId,
    required String userId,
    required int rating,
    required String content,
    List<String> imageUrls = const [],
  }) async {
    final error = insertError;
    if (error != null) throw error;
    return _review('new', rating);
  }

  @override
  Future<List<UploadedReviewImage>> uploadReviewImages({
    required String cafeId,
    required String userId,
    required List<File> images,
    String? accessToken,
  }) async {
    final error = uploadError;
    if (error != null) throw error;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('ReviewsBloc', () {
    test(
      'a slow filtered load cannot land after a newer unfiltered one',
      () async {
        final repo = _GatedReviewsRepository();
        final bloc = ReviewsBloc(
          getCafeReviewsUseCase: GetCafeReviewsUseCase(repo),
        );
        addTearDown(bloc.close);

        // Filter to 5 stars, then clear the filter before it answers.
        bloc.add(const LoadReviewsRequested(cafeId: 'cafe', ratingFilter: 5));
        await pumpEventQueue();
        bloc.add(const LoadReviewsRequested(cafeId: 'cafe'));
        await pumpEventQueue();

        // The unfiltered answer arrives first, the filtered one after it.
        repo.gates[null]!.complete([_review('a', 5), _review('b', 2)]);
        await pumpEventQueue();
        repo.gates[5]!.complete([_review('a', 5)]);
        await pumpEventQueue();

        final state = bloc.state as ReviewsLoaded;
        expect(state.reviews.map((r) => r.id), ['a', 'b']);
      },
    );

    test(
      'a superseded load that fails does not replace the newer result',
      () async {
        final repo = _GatedReviewsRepository();
        final bloc = ReviewsBloc(
          getCafeReviewsUseCase: GetCafeReviewsUseCase(repo),
        );
        addTearDown(bloc.close);

        bloc.add(const LoadReviewsRequested(cafeId: 'cafe', ratingFilter: 5));
        await pumpEventQueue();
        bloc.add(const LoadReviewsRequested(cafeId: 'cafe'));
        await pumpEventQueue();

        repo.gates[null]!.complete([_review('a', 5)]);
        await pumpEventQueue();
        repo.gates[5]!.completeError(Exception('offline'));
        await pumpEventQueue();

        expect(bloc.state, isA<ReviewsLoaded>());
      },
    );
  });

  group('ReviewSubmitBloc error copy', () {
    // An id with "401" in it, as the data source quotes in its message.
    const cafeId = 'a4010000-0000-4000-8000-000000000401';

    Future<String> messageFor({Object? insert, Object? upload}) async {
      final repo = _SubmitRepository()
        ..insertError = insert
        ..uploadError = upload;
      final bloc = ReviewSubmitBloc(
        addReviewUseCase: AddReviewUseCase(repo),
        uploadReviewImagesUseCase: UploadReviewImagesUseCase(repo),
      );
      addTearDown(bloc.close);
      bloc.add(
        const SubmitReviewRequested(
          cafeId: cafeId,
          userId: 'user-1',
          rating: 5,
          content: 'Lovely',
          photos: [],
        ),
      );
      final state = await bloc.stream.firstWhere(
        (s) => s is ReviewSubmitError || s is ReviewSubmitSuccess,
      );
      return (state as ReviewSubmitError).message;
    }

    CafeFetchException wrapped(Object cause) => CafeFetchException(
      'Failed to insert review for cafe id "$cafeId".',
      cause: cause,
    );

    test('digits in the cafe id are not read as a 401', () async {
      expect(
        await messageFor(insert: wrapped(Exception('connection reset'))),
        'Unable to submit your review right now. Please try again.',
      );
    });

    test('a unique violation is "already submitted"', () async {
      expect(
        await messageFor(
          insert: wrapped(
            const PostgrestException(
              message: 'duplicate key value violates unique constraint',
              code: '23505',
            ),
          ),
        ),
        'You already submitted a review for this cafe.',
      );
    });

    test('an RLS refusal asks the user to sign in', () async {
      expect(
        await messageFor(
          insert: wrapped(
            const PostgrestException(
              message: 'new row violates row-level security policy',
              code: '42501',
            ),
          ),
        ),
        'Please sign in to submit a review.',
      );
    });

    test('a failed upload says so', () async {
      expect(
        await messageFor(upload: const UploadException('Upload to S3 failed.')),
        'Image upload failed. Please try again.',
      );
    });

    test('a timeout says so', () async {
      expect(
        await messageFor(
          insert: TimeoutException('Review submission timed out.'),
        ),
        'Submission timed out. Please check your connection and try again.',
      );
    });

    test('an out-of-range rating is named', () async {
      final repo = _SubmitRepository();
      final bloc = ReviewSubmitBloc(
        addReviewUseCase: AddReviewUseCase(repo),
        uploadReviewImagesUseCase: UploadReviewImagesUseCase(repo),
      );
      addTearDown(bloc.close);
      bloc.add(
        const SubmitReviewRequested(
          cafeId: cafeId,
          userId: 'user-1',
          rating: 0,
          content: '',
          photos: [],
        ),
      );
      final state = await bloc.stream.firstWhere((s) => s is ReviewSubmitError);
      expect(
        (state as ReviewSubmitError).message,
        'Please select a rating from 1 to 5.',
      );
    });
  });
}
