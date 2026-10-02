import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_logic.dart';

ReviewEntity _review(String id, String userId, int rating) => ReviewEntity(
  id: id,
  cafeId: 'cafe',
  userId: userId,
  rating: rating,
  content: 'Text $id',
  createdAt: DateTime(2026, 5, 23),
  updatedAt: DateTime(2026, 5, 23),
  name: userId,
);

void main() {
  test('sort options send the values get_reviews_with_vote_status knows', () {
    expect(reviewSortOptions.map((option) => option.value), [
      'recommended',
      'recent',
      'highest',
      'helpful',
    ]);
    expect(reviewSortLabel('recent'), 'Recently added');
  });

  final reviews = [
    _review('r1', 'maria', 5),
    _review('r2', 'jp', 4),
    _review('r3', 'ana', 1),
  ];

  test('draft banner names the day the draft was saved', () {
    expect(
      draftRecoveredLabel(DateTime(2026, 5, 21, 9)),
      'Draft recovered from May 21.',
    );
    expect(draftRecoveredLabel(null), 'Draft recovered.');
    expect(
      draftRecoveredLabel(DateTime.fromMillisecondsSinceEpoch(0)),
      'Draft recovered.',
    );
  });

  test('photo label counts from zero', () {
    expect(photoCountLabel(0, 3), 'Optional · 0 of 3');
    expect(photoCountLabel(2, 3), 'Optional · 2 of 3');
  });

  test('hasOwnReview is false for a guest and true for the author', () {
    expect(hasOwnReview(reviews, null), isFalse);
    expect(hasOwnReview(reviews, 'someone-else'), isFalse);
    expect(hasOwnReview(reviews, 'jp'), isTrue);
  });

  test('visibleReviews drops blocked authors and deleted reviews', () {
    expect(visibleReviews(reviews).map((r) => r.id), ['r1', 'r2', 'r3']);
    expect(
      visibleReviews(
        reviews,
        blockedUserIds: {'ana'},
        deletedReviewIds: {'r1'},
      ).map((r) => r.id),
      ['r2'],
    );
  });

  test('summary follows the block list', () {
    final before = ReviewsSummary.from(visibleReviews(reviews));
    final after = ReviewsSummary.from(
      visibleReviews(reviews, blockedUserIds: {'ana'}),
    );

    expect(before.total, 3);
    expect(before.countFor(1), 1);
    expect(after.total, 2);
    expect(after.countFor(1), 0);
    expect(after.average, 4.5);
  });

  test('own review is pinned first', () {
    expect(pinOwnReviewFirst(reviews, 'ana').map((r) => r.id), [
      'r3',
      'r1',
      'r2',
    ]);
    expect(pinOwnReviewFirst(reviews, null), same(reviews));
  });
}
