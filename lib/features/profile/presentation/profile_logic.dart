import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/utils/content_filter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

/// Pure helpers behind the profile screens: copy, sorting and the username
/// rules. No widgets, so they can be tested directly.

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
String formatReviewDate(DateTime date) {
  return '${_months[date.month - 1]} ${date.day}, ${date.year}';
}

/// "1 review", "12 reviews".
String reviewCountLabel(int count) =>
    '$count ${count == 1 ? 'review' : 'reviews'}';

/// "1 list", "3 lists".
String listCountLabel(int count) => '$count ${count == 1 ? 'list' : 'lists'}';

/// "1 place", "2 places".
String placeCountLabel(int count) =>
    '$count ${count == 1 ? 'place' : 'places'}';

/// The line under the name: "5 ranked · 12 reviews · 3 lists". Ranked leads
/// when there is any, since ranking is what most people do here; the lists
/// half is left out until the lists have loaded.
String profileCountsLine({required int reviews, int? lists, int ranked = 0}) {
  final parts = [
    if (ranked > 0) '$ranked ranked',
    reviewCountLabel(reviews),
    if (lists != null) listCountLabel(lists),
  ];
  return parts.join(' · ');
}

/// The order of the "Your reviews" page.
enum ProfileReviewSort {
  mostRecent('Most recent'),
  oldest('Oldest'),
  highestRated('Highest rated'),
  lowestRated('Lowest rated');

  const ProfileReviewSort(this.label);

  final String label;
}

/// [all] narrowed to [rating] stars (null keeps every review) and put in
/// [sort] order.
List<WrittenReview> filterAndSortReviews(
  List<WrittenReview> all, {
  int? rating,
  ProfileReviewSort sort = ProfileReviewSort.mostRecent,
}) {
  final result = [
    for (final review in all)
      if (rating == null || review.rating == rating) review,
  ];
  switch (sort) {
    case ProfileReviewSort.mostRecent:
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case ProfileReviewSort.oldest:
      result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    case ProfileReviewSort.highestRated:
      result.sort((a, b) => b.rating.compareTo(a.rating));
    case ProfileReviewSort.lowestRated:
      result.sort((a, b) => a.rating.compareTo(b.rating));
  }
  return result;
}

/// What the profile shows for an account with no name. It is a label, not a
/// value: it must never be written back to `profiles.full_name`.
const noNamePlaceholder = 'No name';

/// The name the edit form starts from: empty when the account has none, so
/// the placeholder is never offered as text to save.
String editableName(String name) =>
    name.trim() == noNamePlaceholder ? '' : name;

/// What to write to `full_name` for [typed], or null to leave it alone:
/// nothing changed, nothing typed, or only the placeholder.
String? profileNameToSave(String typed, {required String saved}) {
  final name = typed.trim();
  if (name.isEmpty || name == noNamePlaceholder) return null;
  return name == saved.trim() ? null : name;
}

/// The server's limit on `profiles.bio`, counted in code points. The field
/// stops at 150 characters as the user sees them, but one emoji can be
/// several code points, so a short-looking bio can still be over.
const bioMaxCodePoints = 500;

/// Whether [typed] differs from the saved username only by letter case.
/// The availability check would report the user's own name as taken.
bool isCaseOnlyUsernameChange(String typed, String saved) =>
    typed != saved && typed.toLowerCase() == saved.toLowerCase();

/// Why [value] cannot be a username, or null when it can.
String? validateUsername(String value) {
  if (value.isEmpty) return 'Username cannot be empty';
  if (value.length < 3) return 'At least 3 characters';
  if (value.length > 20) return 'Max 20 characters';
  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
    return 'Only letters, numbers, and underscores';
  }
  if (ContentFilter.containsObjectionable(value)) {
    return 'This username is not allowed';
  }
  return null;
}

/// A username can be changed once every this many days.
const usernameCooldownDays = 14;

/// Days left before the username can change again; 0 when it can change now.
int usernameCooldownDaysLeft(DateTime? lastChange, {DateTime? now}) {
  if (lastChange == null) return 0;
  final elapsed = (now ?? DateTime.now()).difference(lastChange).inDays;
  return elapsed < usernameCooldownDays ? usernameCooldownDays - elapsed : 0;
}

/// What the helper line under the username field is reporting.
enum UsernameStatus {
  /// Unchanged from the saved username: the rules are shown.
  unchanged,
  checking,
  available,
  taken,
  invalid,

  /// The availability check failed, so nothing is known.
  unknown,

  /// Inside the cooldown: the field cannot be edited.
  locked,
}

/// True when the account signs in with an email and password, false for
/// Google and Apple accounts.
bool isEmailPasswordUser(User user) {
  final identities = user.identities;
  if (identities == null || identities.isEmpty) {
    return user.appMetadata['provider'] == 'email' ||
        (user.appMetadata['providers'] is List &&
            (user.appMetadata['providers'] as List).contains('email'));
  }
  return identities.any((i) => i.provider == 'email');
}

/// "Google" or "Apple" for an account that signs in with one of them; null
/// for email accounts and providers with no display name.
String? socialProviderName(User user) {
  if (isEmailPasswordUser(user)) return null;
  final providers = <String>[
    for (final identity in user.identities ?? const []) identity.provider,
    if (user.appMetadata['provider'] is String)
      user.appMetadata['provider'] as String,
  ];
  if (providers.contains('google')) return 'Google';
  if (providers.contains('apple')) return 'Apple';
  return null;
}
