import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

/// Pure helpers for the Reviews page: labels, the rating filter toggle, the
/// score summary and image URL repair. No widgets, so they can be unit tested.

/// The sort values the reviews query accepts, with the label each one shows.
const List<({String value, String label})> reviewSortOptions = [
  (value: 'recommended', label: 'Recommended'),
  (value: 'recent', label: 'Recently added'),
  (value: 'highest', label: 'Highest rated'),
  (value: 'helpful', label: 'Most helpful'),
];

String reviewSortLabel(String value) {
  for (final option in reviewSortOptions) {
    if (option.value == value) return option.label;
  }
  return reviewSortOptions.first.label;
}

/// "1 review", "32 reviews".
String reviewCountLabel(int count) =>
    count == 1 ? '1 review' : '$count reviews';

/// "Helpful" with no votes, "Helpful · 6" otherwise.
String helpfulLabel(int count) => count <= 0 ? 'Helpful' : 'Helpful · $count';

/// Tapping the active rating row clears the filter; any other row selects it.
int? toggleRatingFilter(int? current, int tapped) =>
    current == tapped ? null : tapped;

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "May 23, 2026".
String formatReviewDate(DateTime date) =>
    '${_months[date.month - 1]} ${date.day}, ${date.year}';

/// "Draft recovered from May 21." Just "Draft recovered." when the draft
/// carries no usable date (older drafts were saved without one).
String draftRecoveredLabel(DateTime? savedAt) {
  if (savedAt == null || savedAt.millisecondsSinceEpoch <= 0) {
    return 'Draft recovered.';
  }
  return 'Draft recovered from ${_months[savedAt.month - 1]} ${savedAt.day}.';
}

/// "Optional · 0 of 3".
String photoCountLabel(int count, int max) => 'Optional · $count of $max';

/// Whether [currentUserId] already has a review in [reviews]. The app allows
/// one review per cafe, so this hides every way into writing another.
bool hasOwnReview(List<ReviewEntity> reviews, String? currentUserId) =>
    currentUserId != null && reviews.any((r) => r.userId == currentUserId);

/// The reviews a viewer may see: nothing from blocked authors, and nothing
/// they deleted a moment ago that the server list has not dropped yet.
List<ReviewEntity> visibleReviews(
  List<ReviewEntity> reviews, {
  Set<String> blockedUserIds = const {},
  Set<String> deletedReviewIds = const {},
}) => reviews
    .where(
      (r) =>
          !blockedUserIds.contains(r.userId) &&
          !deletedReviewIds.contains(r.id),
    )
    .toList();

/// What the header shows: the average, the total, and how many reviews each
/// star has. Built from an unfiltered list so the rows stay stable while one
/// of them is used as the filter.
class ReviewsSummary {
  const ReviewsSummary({
    required this.average,
    required this.total,
    required this.counts,
  });

  const ReviewsSummary.empty() : average = 0, total = 0, counts = const {};

  factory ReviewsSummary.from(List<ReviewEntity> reviews) {
    final counts = <int, int>{};
    var sum = 0;
    for (final review in reviews) {
      counts[review.rating] = (counts[review.rating] ?? 0) + 1;
      sum += review.rating;
    }
    return ReviewsSummary(
      average: reviews.isEmpty ? 0 : sum / reviews.length,
      total: reviews.length,
      counts: counts,
    );
  }

  final double average;
  final int total;
  final Map<int, int> counts;

  int countFor(int star) => counts[star] ?? 0;

  /// Share of all reviews with [star], 0 to 1.
  double fractionFor(int star) => total == 0 ? 0 : countFor(star) / total;
}

/// Puts the signed-in user's own review first, keeping the rest in order.
List<ReviewEntity> pinOwnReviewFirst(
  List<ReviewEntity> reviews,
  String? currentUserId,
) {
  if (currentUserId == null) return reviews;
  final own = reviews.where((r) => r.userId == currentUserId).toList();
  if (own.isEmpty) return reviews;
  return [...own, ...reviews.where((r) => r.userId != currentUserId)];
}

/// Repairs the malformed photo URLs some older reviews carry (doubled
/// schemes, protocol-relative, http) so they load. Empty when unusable.
String resolveReviewImageUrl(String raw) {
  var candidate = raw.trim();
  if (candidate.isEmpty) return '';

  if ((candidate.startsWith('"') && candidate.endsWith('"')) ||
      (candidate.startsWith("'") && candidate.endsWith("'"))) {
    candidate = candidate.substring(1, candidate.length - 1).trim();
  }

  if (candidate.startsWith('//')) {
    candidate = 'https:$candidate';
  }

  while (true) {
    final lowered = candidate.toLowerCase();
    if (lowered.startsWith('https://https://')) {
      candidate = 'https://${candidate.substring('https://https://'.length)}';
      continue;
    }
    if (lowered.startsWith('http://http://')) {
      candidate = 'http://${candidate.substring('http://http://'.length)}';
      continue;
    }
    if (lowered.startsWith('http://https://')) {
      candidate = 'https://${candidate.substring('http://https://'.length)}';
      continue;
    }
    if (lowered.startsWith('https://http://')) {
      candidate = 'https://${candidate.substring('https://http://'.length)}';
      continue;
    }
    break;
  }

  Uri? parsed;
  try {
    parsed = Uri.parse(candidate);
  } catch (_) {
    return '';
  }

  if ((parsed.host == 'https' || parsed.host == 'http') &&
      parsed.path.startsWith('//')) {
    candidate = 'https:${parsed.path}';
    try {
      parsed = Uri.parse(candidate);
    } catch (_) {
      return '';
    }
  }

  if (!parsed.hasScheme) {
    candidate = 'https://$candidate';
    try {
      parsed = Uri.parse(candidate);
    } catch (_) {
      return '';
    }
  }

  if (parsed.scheme == 'http' &&
      parsed.host.isNotEmpty &&
      parsed.host != 'localhost' &&
      parsed.host != '127.0.0.1') {
    parsed = parsed.replace(scheme: 'https');
  }

  return parsed.toString();
}
