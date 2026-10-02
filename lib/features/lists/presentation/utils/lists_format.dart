/// "1 place" / "4 places".
String placeCountText(int count) => '$count ${count == 1 ? 'place' : 'places'}';

/// "yesterday" / "3 days ago" / "last week". Coarse on purpose — the point is
/// which list was touched most recently, not an audit trail.
String relativeDay(DateTime when, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final days = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(when.year, when.month, when.day)).inDays;

  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  if (days < 14) return 'last week';
  if (days < 30) return '${days ~/ 7} weeks ago';
  if (days < 60) return 'last month';
  if (days < 365) return '${days ~/ 30} months ago';
  return 'over a year ago';
}
