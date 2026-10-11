import 'package:equatable/equatable.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';

/// One person's latest cups at a cafe, played as a story: their photos
/// oldest first, as Instagram plays a person's stories, so the newest is
/// the one you end on.
class CafeStory extends Equatable {
  const CafeStory({required this.credit, required this.photos});

  final PhotoCredit credit;

  /// Oldest first. Never empty.
  final List<CommunityPhoto> photos;

  /// The newest photo: the one the tray shows for this person.
  CommunityPhoto get latest => photos.last;

  DateTime get latestAt => latest.photo.takenAt;

  /// Every photo of this story is in [seen].
  bool isSeenIn(Set<String> seen) => photos.every((p) => seen.contains(p.id));

  /// Where to start playing: the first photo not in [seen], or the first
  /// when all have been seen (a rewatch starts at the beginning).
  int startIndexFor(Set<String> seen) {
    final i = photos.indexWhere((p) => !seen.contains(p.id));
    return i < 0 ? 0 : i;
  }

  @override
  List<Object?> get props => [credit, photos];
}

/// Groups a cafe's community photos per person, newest person first (by
/// their newest photo), each person's photos oldest first.
///
/// [photos] may come in any order. Ties on the date keep the order the
/// repository gave (newest id first), so the grouping is stable.
List<CafeStory> groupCafeStories(List<CommunityPhoto> photos) {
  final byUser = <String, List<CommunityPhoto>>{};
  final credits = <String, PhotoCredit>{};
  for (final photo in photos) {
    final id = photo.credit.userId;
    (byUser[id] ??= []).add(photo);
    credits[id] ??= photo.credit;
  }
  final stories = [
    for (final entry in byUser.entries)
      CafeStory(credit: credits[entry.key]!, photos: _oldestFirst(entry.value)),
  ];
  final order = {for (var i = 0; i < stories.length; i++) stories[i]: i};
  stories.sort((a, b) {
    final byDate = b.latestAt.compareTo(a.latestAt);
    return byDate != 0 ? byDate : order[a]!.compareTo(order[b]!);
  });
  return List.unmodifiable(stories);
}

List<CommunityPhoto> _oldestFirst(List<CommunityPhoto> photos) {
  final indexed = [for (var i = 0; i < photos.length; i++) (i, photos[i])];
  indexed.sort((a, b) {
    final byDate = a.$2.photo.takenAt.compareTo(b.$2.photo.takenAt);
    // Same date: the later one in the newest-first input is the older.
    return byDate != 0 ? byDate : b.$1.compareTo(a.$1);
  });
  return List.unmodifiable([for (final e in indexed) e.$2]);
}

/// "now", "12m", "5h", "3d", "2w", then "Jul 2026": short enough for the
/// viewer's header line. Past the first weeks a day count stops meaning
/// much, and an EXIF date may not be that precise anyway.
String storyAgeLabel(DateTime takenAt, DateTime now) {
  final age = now.difference(takenAt);
  if (age.isNegative || age.inMinutes < 1) return 'now';
  if (age.inHours < 1) return '${age.inMinutes}m';
  if (age.inDays < 1) return '${age.inHours}h';
  if (age.inDays < 7) return '${age.inDays}d';
  if (age.inDays < 35) return '${age.inDays ~/ 7}w';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[takenAt.month - 1]} ${takenAt.year}';
}

/// The review a review photo came from, as the story viewer shows it under
/// the photo (Cups, phase 1: docs REVIEWS_GALLERY_MERGE.md). Read only.
class StoryReview extends Equatable {
  const StoryReview({required this.rating, required this.text});

  /// 1 to 5 stars.
  final int rating;
  final String text;

  @override
  List<Object?> get props => [rating, text];
}
