import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/profile/presentation/profile_logic.dart';

import 'profile_test_support.dart';

void main() {
  test('formatReviewDate spells the month', () {
    expect(formatReviewDate(DateTime(2026, 5, 23)), 'May 23, 2026');
    expect(formatReviewDate(DateTime(2026, 12, 1)), 'Dec 1, 2026');
  });

  test('counts read naturally in the singular and plural', () {
    expect(reviewCountLabel(1), '1 review');
    expect(reviewCountLabel(12), '12 reviews');
    expect(placeCountLabel(1), '1 place');
    expect(profileCountsLine(reviews: 12, lists: 3), '12 reviews · 3 lists');
    expect(profileCountsLine(reviews: 0, lists: 1), '0 reviews · 1 list');
    // Lists not loaded yet: say nothing about them.
    expect(profileCountsLine(reviews: 2), '2 reviews');
  });

  group('filterAndSortReviews', () {
    final reviews = [
      review('a', rating: 5, at: DateTime(2026, 5, 23)),
      review('b', rating: 4, at: DateTime(2026, 5, 12)),
      review('c', rating: 2, at: DateTime(2026, 4, 30)),
      review('d', rating: 5, at: DateTime(2026, 4, 11)),
    ];

    List<String> ids({int? rating, ProfileReviewSort? sort}) => [
      for (final r in filterAndSortReviews(
        reviews,
        rating: rating,
        sort: sort ?? ProfileReviewSort.mostRecent,
      ))
        r.id,
    ];

    test('newest first by default', () {
      expect(ids(), ['a', 'b', 'c', 'd']);
    });

    test('oldest first', () {
      expect(ids(sort: ProfileReviewSort.oldest), ['d', 'c', 'b', 'a']);
    });

    test('by rating', () {
      expect(ids(sort: ProfileReviewSort.lowestRated).first, 'c');
      expect(ids(sort: ProfileReviewSort.highestRated).last, 'c');
    });

    test('a rating keeps only that many stars', () {
      expect(ids(rating: 5), ['a', 'd']);
      expect(ids(rating: 1), isEmpty);
    });

    test('leaves the input list alone', () {
      ids(sort: ProfileReviewSort.oldest);
      expect(reviews.first.id, 'a');
    });
  });

  test('validateUsername names what is wrong', () {
    expect(validateUsername('sai_brews'), isNull);
    expect(validateUsername(''), 'Username cannot be empty');
    expect(validateUsername('ab'), 'At least 3 characters');
    expect(validateUsername('a' * 21), 'Max 20 characters');
    expect(
      validateUsername('sai brews!'),
      'Only letters, numbers, and underscores',
    );
  });

  test('the "No name" placeholder is never text to edit or save', () {
    expect(editableName('No name'), '');
    expect(editableName('Sai'), 'Sai');

    // Untouched, emptied, or the placeholder itself: nothing is written.
    expect(profileNameToSave('', saved: ''), isNull);
    expect(profileNameToSave('  ', saved: 'Sai'), isNull);
    expect(profileNameToSave('No name', saved: ''), isNull);
    expect(profileNameToSave('Sai', saved: 'Sai'), isNull);
    expect(profileNameToSave(' Sai ', saved: 'Sai'), isNull);
    // A real change is written, trimmed.
    expect(profileNameToSave(' Simon ', saved: 'Sai'), 'Simon');
    expect(profileNameToSave('Simon', saved: ''), 'Simon');
  });

  test('a case-only username change is recognised', () {
    expect(isCaseOnlyUsernameChange('Saiimonn_', 'saiimonn_'), isTrue);
    expect(isCaseOnlyUsernameChange('saiimonn_', 'saiimonn_'), isFalse);
    expect(isCaseOnlyUsernameChange('sai_brews', 'saiimonn_'), isFalse);
  });

  test('usernameCooldownDaysLeft counts down from 14 days', () {
    final now = DateTime(2026, 6, 15);
    expect(usernameCooldownDaysLeft(null, now: now), 0);
    expect(usernameCooldownDaysLeft(DateTime(2026, 6, 10), now: now), 9);
    expect(usernameCooldownDaysLeft(DateTime(2026, 6, 1), now: now), 0);
  });

  test('accounts are told apart by how they sign in', () {
    expect(isEmailPasswordUser(userWith('email')), isTrue);
    expect(socialProviderName(userWith('email')), isNull);

    expect(isEmailPasswordUser(userWith('google')), isFalse);
    expect(socialProviderName(userWith('google')), 'Google');
    expect(socialProviderName(userWith('apple')), 'Apple');
  });
}
