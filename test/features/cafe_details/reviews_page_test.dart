import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/block/domain/repositories/i_block_repository.dart';
import 'package:nook/core/block/domain/use_cases/block_user_usecase.dart';
import 'package:nook/core/block/domain/use_cases/get_blocked_user_ids_usecase.dart';
import 'package:nook/core/block/domain/use_cases/unblock_user_usecase.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_reviews_usecase.dart';
import 'package:nook/core/cafe/domain/use_cases/report_review_usecase.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_bloc.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_event.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_state.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_event.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/pages/reviews_page.dart';
import 'package:nook/utils/theme/theme.dart';

class _NoCafeRepository implements ICafeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Serves [reviews], or throws [error] when set.
class _FakeGetReviews extends GetCafeReviewsUseCase {
  _FakeGetReviews(this.reviews) : super(_NoCafeRepository());

  List<Review> reviews;
  Object? error;
  int calls = 0;

  @override
  Future<List<Review>> call(
    String cafeId, {
    String sort = 'recommended',
    int? ratingFilter,
  }) async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return reviews
        .where((r) => ratingFilter == null || r.rating == ratingFilter)
        .toList();
  }
}

class _RecordingReportRepository implements ICafeRepository {
  final calls =
      <({String reviewId, String cafeId, String reporterId, String reason})>[];

  @override
  Future<void> reportReview({
    required String reviewId,
    required String cafeId,
    required String reporterId,
    required String reasonCode,
    String? description,
  }) async {
    calls.add((
      reviewId: reviewId,
      cafeId: cafeId,
      reporterId: reporterId,
      reason: reasonCode,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSubmitBloc extends Bloc<ReviewSubmitEvent, ReviewSubmitState>
    implements ReviewSubmitBloc {
  _FakeSubmitBloc() : super(const ReviewSubmitInitial());

  void push(ReviewSubmitState state) => emit(state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBlockRepository implements IBlockRepository {
  @override
  Future<void> blockUser(String blockedUserId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Review _review(String id, String userId, int rating) => Review(
  id: id,
  cafeId: 'cafe',
  userId: userId,
  rating: rating,
  content: 'Review text from $userId',
  createdAt: DateTime(2026, 5, 23),
  updatedAt: DateTime(2026, 5, 23),
  name: userId,
);

class _Harness {
  _Harness(List<Review> reviews) : getReviews = _FakeGetReviews(reviews) {
    final repo = _FakeBlockRepository();
    blockCubit = BlockCubit(
      blockUser: BlockUserUseCase(repo),
      unblockUser: UnblockUserUseCase(repo),
      getBlockedIds: GetBlockedUserIdsUseCase(repo),
    );
  }

  final _FakeGetReviews getReviews;
  final submitBloc = _FakeSubmitBloc();
  late final BlockCubit blockCubit;
  final deleted = <String>[];

  /// Set to open the page on a bloc that has already loaded, as it is when
  /// reached from the cafe details page.
  ReviewsBloc? sharedBloc;

  Future<void> pump(WidgetTester tester, {String? userId}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<BlockCubit>.value(value: blockCubit),
          if (sharedBloc case final bloc?)
            BlocProvider<ReviewsBloc>.value(value: bloc)
          else
            BlocProvider<ReviewsBloc>(
              create: (_) => ReviewsBloc(getCafeReviewsUseCase: getReviews),
            ),
          BlocProvider<ReviewSubmitBloc>.value(value: submitBloc),
        ],
        child: MaterialApp(
          theme: TAppTheme.lightTheme,
          home: ReviewsPage(
            cafeId: 'cafe',
            cafeName: 'Tadaima',
            currentUserId: () => userId,
            deleteReview: (id) async {
              deleted.add(id);
              getReviews.reviews = getReviews.reviews
                  .where((r) => r.id != id)
                  .toList();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

void main() {
  final others = [_review('r2', 'jp_dev', 4), _review('r3', 'ana.reyes', 1)];

  testWidgets('own review: pinned and labelled, Write bar gone', (
    tester,
  ) async {
    final harness = _Harness([...others, _review('r1', 'maria.c', 5)]);
    await harness.pump(tester, userId: 'maria.c');

    final label = tester.widget<Text>(find.text('Your review · May 23, 2026'));
    expect(label.style?.color, const Color(0xFF344E41));
    expect(label.style?.fontSize, 10);
    expect(find.text('Write a review'), findsNothing);
    expect(find.text('3 reviews'), findsNWidgets(2));
    // Own row first.
    expect(
      tester.getTopLeft(find.text('Review text from maria.c')).dy,
      lessThan(tester.getTopLeft(find.text('Review text from jp_dev')).dy),
    );
  });

  testWidgets('deleting your review updates the list and restores Write', (
    tester,
  ) async {
    final harness = _Harness([...others, _review('r1', 'maria.c', 5)]);
    await harness.pump(tester, userId: 'maria.c');

    await tester.tap(find.bySemanticsLabel('Review options').first);
    await tester.pumpAndSettle();
    expect(find.text('Your review'), findsOneWidget);
    expect(find.text('Report review'), findsNothing);

    await tester.tap(find.text('Delete review'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your review?'), findsOneWidget);

    await tester.tap(find.text('Delete review'));
    await tester.pumpAndSettle();

    expect(harness.deleted, ['r1']);
    expect(find.text('Review deleted'), findsOneWidget);
    expect(find.text('Review text from maria.c'), findsNothing);
    expect(find.text('2 reviews'), findsNWidgets(2));
    expect(find.text('Write a review'), findsOneWidget);

    // Let the toast close so no timer outlives the test.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the delete keeps the review', (tester) async {
    final harness = _Harness([_review('r1', 'maria.c', 5)]);
    await harness.pump(tester, userId: 'maria.c');

    await tester.tap(find.bySemanticsLabel('Review options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(harness.deleted, isEmpty);
    expect(find.text('Review text from maria.c'), findsOneWidget);
  });

  testWidgets('guest: Write, Helpful and Report ask to sign in', (
    tester,
  ) async {
    final harness = _Harness(others);
    await harness.pump(tester);

    await tester.tap(find.text('Write a review'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to write a review'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to write a review'), findsNothing);

    await tester.tap(find.text('Helpful').first);
    await tester.pumpAndSettle();
    expect(find.text('Sign in to mark reviews helpful'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    // Guests get the ⋯ too, and Report routes through the same sheet.
    expect(find.bySemanticsLabel('Review options'), findsNWidgets(2));
    await tester.tap(find.bySemanticsLabel('Review options').first);
    await tester.pumpAndSettle();
    expect(find.text('Review by jp_dev'), findsOneWidget);
    await tester.tap(find.text('Report review'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to report a review'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('load error: shared copy, one action, no Write bar', (
    tester,
  ) async {
    final harness = _Harness(others)
      ..getReviews.error = const SocketException('offline');
    await harness.pump(tester, userId: 'maria.c');

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Check your connection and try again'), findsOneWidget);
    expect(find.text('Write a review'), findsNothing);

    harness.getReviews.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text("You're offline"), findsNothing);
    expect(find.text('Write a review'), findsOneWidget);
  });

  testWidgets('blocking an author recomputes the score and the count', (
    tester,
  ) async {
    final harness = _Harness(others);
    await harness.pump(tester, userId: 'maria.c');

    expect(find.text('2.5'), findsOneWidget);
    expect(find.text('2 reviews'), findsNWidgets(2));

    await harness.blockCubit.block('ana.reyes');
    await tester.pumpAndSettle();

    expect(find.text('4.0'), findsOneWidget);
    expect(find.text('1 review'), findsNWidgets(2));
    expect(find.text('Review text from ana.reyes'), findsNothing);
  });

  testWidgets('a rating row filters the rows already loaded', (tester) async {
    final harness = _Harness(others);
    await harness.pump(tester, userId: 'maria.c');
    expect(harness.getReviews.calls, 1);
    // Room for the filter chip beside the count in the test font.
    tester.view.physicalSize = const Size(600, 844);
    await tester.pump();

    await tester.tap(find.bySemanticsLabel(RegExp('^4 star')));
    await tester.pumpAndSettle();

    expect(find.text('Review text from jp_dev'), findsOneWidget);
    expect(find.text('Review text from ana.reyes'), findsNothing);
    // The score still covers every review, and nothing was asked for again.
    expect(find.text('2.5'), findsOneWidget);
    expect(harness.getReviews.calls, 1);
  });

  testWidgets('opened over loaded reviews, the page does not ask again', (
    tester,
  ) async {
    final harness = _Harness(others);
    final bloc = ReviewsBloc(getCafeReviewsUseCase: harness.getReviews);
    addTearDown(bloc.close);
    bloc.add(const LoadReviewsRequested(cafeId: 'cafe'));
    await bloc.stream.firstWhere((s) => s is ReviewsLoaded);
    expect(harness.getReviews.calls, 1);

    harness.sharedBloc = bloc;
    await harness.pump(tester, userId: 'maria.c');

    expect(find.text('Review text from jp_dev'), findsOneWidget);
    expect(find.text('2.5'), findsOneWidget);
    expect(find.text('Write a review'), findsOneWidget);
    expect(harness.getReviews.calls, 1);
  });

  testWidgets('posting while a rating filter is on still updates the totals', (
    tester,
  ) async {
    final harness = _Harness(others);
    await harness.pump(tester, userId: 'maria.c');

    // The test font is far wider than Poppins: give the count, the filter
    // chip and the sort pill the room they have on a phone.
    tester.view.physicalSize = const Size(600, 844);
    await tester.pump();

    // Filter to 1 star: one of the two reviews.
    await tester.tap(find.bySemanticsLabel(RegExp('^1 star, 1 review')));
    await tester.pumpAndSettle();
    expect(find.text('Write a review'), findsOneWidget);

    // The user posts a 5-star review; the server now has three.
    final mine = _review('r1', 'maria.c', 5);
    harness.getReviews.reviews = [...others, mine];
    harness.submitBloc.push(
      ReviewSubmitSuccess(
        review: ReviewEntity(
          id: mine.id,
          cafeId: mine.cafeId,
          userId: mine.userId,
          rating: mine.rating,
          content: mine.content,
          createdAt: mine.createdAt,
          updatedAt: mine.updatedAt,
          name: mine.name,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The filter stays, the totals move, and a second review is not offered.
    expect(find.bySemanticsLabel(RegExp('^5 star, 1 review')), findsOneWidget);
    expect(find.text('3 reviews'), findsOneWidget);
    expect(find.text('Write a review'), findsNothing);
  });

  testWidgets('reporting files the page\'s cafe id when the review has none', (
    tester,
  ) async {
    final reports = _RecordingReportRepository();
    GetIt.instance.registerSingleton<ReportReviewUseCase>(
      ReportReviewUseCase(reports),
    );
    addTearDown(GetIt.instance.reset);

    // The reviews RPC returns no cafe_id, so rows arrive with an empty one.
    final harness = _Harness([
      Review(
        id: 'r2',
        cafeId: '',
        userId: 'jp_dev',
        rating: 4,
        content: 'Review text from jp_dev',
        createdAt: DateTime(2026, 5, 23),
        updatedAt: DateTime(2026, 5, 23),
        name: 'jp_dev',
      ),
    ]);
    await harness.pump(tester, userId: 'maria.c');

    await tester.tap(find.bySemanticsLabel('Review options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report review'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Spam or advertising'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit report'));
    await tester.pumpAndSettle();

    expect(reports.calls, [
      (reviewId: 'r2', cafeId: 'cafe', reporterId: 'maria.c', reason: 'spam'),
    ]);
    expect(
      find.text('Could not submit the report. Please retry.'),
      findsNothing,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
