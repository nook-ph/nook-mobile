/// Resolves a cafe's `operating_hours` JSON into an open/closed state.
///
/// Ported from nook-webapp's `lib/utils/hours.ts` so both clients agree on the
/// same cafe at the same moment, with one deliberate difference: a day whose
/// open and close times are identical resolves to [CafeOpenState.unknown] here
/// rather than "closed". Two cafes store `00:00`-`00:00` for all seven days as
/// a placeholder, and on a card "Closed" reads as a fact about the cafe rather
/// than a gap in our data. Callers render nothing for [CafeOpenState.unknown].
library;

enum CafeOpenState {
  open,

  /// Open, but within [CafeOpenStatus.closingSoonThreshold] of closing. Worth
  /// distinguishing on a map card: the whole point of the badge is to stop
  /// someone walking 15 minutes to a cafe that shuts as they arrive.
  closingSoon,

  closed,

  /// Hours are missing, malformed, or a placeholder. Render nothing.
  unknown,
}

/// Cafe hours are stored as Philippine wall-clock times with no zone attached,
/// so "now" has to be resolved in Manila rather than the device zone — a user
/// whose phone is set to another zone (or who is travelling) would otherwise
/// see the wrong day's hours entirely. PH has been a fixed UTC+8 with no DST
/// since 1978, so a constant offset is exact and avoids pulling in the `tz`
/// database for a single lookup.
const Duration _manilaOffset = Duration(hours: 8);

/// Indexed by `DateTime.weekday - 1` (Dart weekdays run Monday=1..Sunday=7).
const List<String> _dayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

const int _minutesPerDay = 24 * 60;

final RegExp _hhmm = RegExp(r'^(\d{1,2}):(\d{2})$');

class CafeOpenStatus {
  const CafeOpenStatus._(this.state, this.minutesUntilClose);

  final CafeOpenState state;

  /// Minutes remaining until the cafe closes; null unless [state] is
  /// [CafeOpenState.open] or [CafeOpenState.closingSoon].
  final int? minutesUntilClose;

  static const CafeOpenStatus unknown = CafeOpenStatus._(
    CafeOpenState.unknown,
    null,
  );
  static const CafeOpenStatus closed = CafeOpenStatus._(
    CafeOpenState.closed,
    null,
  );

  static const Duration closingSoonThreshold = Duration(minutes: 45);

  bool get isOpen =>
      state == CafeOpenState.open || state == CafeOpenState.closingSoon;

  /// [operatingHours] is the raw `cafes.operating_hours` JSON: a map of day
  /// name to `{open, close, closed}`. [now] defaults to the current instant and
  /// exists for tests; it is converted to Manila time either way, so passing a
  /// UTC or local `DateTime` gives the same answer.
  static CafeOpenStatus resolve(
    Map<String, dynamic>? operatingHours, {
    DateTime? now,
  }) {
    if (operatingHours == null || operatingHours.isEmpty) {
      return unknown;
    }

    final manilaNow = (now ?? DateTime.now()).toUtc().add(_manilaOffset);
    final nowMinutes = manilaNow.hour * 60 + manilaNow.minute;

    final todayKey = _dayKeys[manilaNow.weekday - 1];
    final yesterdayKey = _dayKeys[(manilaNow.weekday + 5) % 7];

    final today = _DayHours.parse(operatingHours[todayKey]);
    final yesterday = _DayHours.parse(operatingHours[yesterdayKey]);

    // Both spans are expressed in minutes relative to today 00:00, so a span
    // that runs past midnight is a single continuous interval instead of two
    // special cases. Yesterday's is checked first: at 01:00 a cafe that opened
    // at 18:00 yesterday and closes at 03:00 is open *now*, and today's own
    // entry says nothing about it.
    for (final span in [
      yesterday?.spanFrom(-_minutesPerDay),
      today?.spanFrom(0),
    ]) {
      if (span == null) continue;
      if (nowMinutes >= span.start && nowMinutes < span.end) {
        final remaining = span.end - nowMinutes;
        return CafeOpenStatus._(
          remaining <= closingSoonThreshold.inMinutes
              ? CafeOpenState.closingSoon
              : CafeOpenState.open,
          remaining,
        );
      }
    }

    // Nothing covers now. Only claim "closed" when today's entry was actually
    // readable — otherwise we are reporting our own missing data as a fact
    // about the cafe.
    if (today == null) return unknown;
    return closed;
  }
}

/// A single day's parsed hours. A day marked closed has no span; a day that
/// failed to parse is represented by a null `_DayHours` instead.
class _DayHours {
  const _DayHours._(this.openMinutes, this.closeMinutes);

  /// Null on a day the cafe is shut — parsed successfully, just no span.
  final int? openMinutes;
  final int? closeMinutes;

  static _DayHours? parse(dynamic raw) {
    if (raw is! Map) return null;

    if (raw['closed'] == true) return const _DayHours._(null, null);

    final open = _parseHhmm(raw['open']);
    final close = _parseHhmm(raw['close']);
    if (open == null || close == null) return null;

    // `00:00`-`00:00` (and any other zero-length span) is a placeholder, not a
    // 24-hour cafe. Treated as unparseable so the caller reports unknown.
    if (open == close) return null;

    return _DayHours._(open, close);
  }

  /// The opening interval as `[start, end)` minutes offset from [dayStart].
  /// A close time at or before the open time means the span runs past midnight,
  /// so it ends on the following day.
  _Span? spanFrom(int dayStart) {
    final open = openMinutes;
    final close = closeMinutes;
    if (open == null || close == null) return null;

    final end = close > open ? close : close + _minutesPerDay;
    return _Span(dayStart + open, dayStart + end);
  }

  static int? _parseHhmm(dynamic value) {
    if (value is! String) return null;
    final match = _hhmm.firstMatch(value.trim());
    if (match == null) return null;

    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    if (hours > 24 || minutes > 59) return null;
    if (hours == 24 && minutes != 0) return null;

    return hours * 60 + minutes;
  }
}

class _Span {
  const _Span(this.start, this.end);
  final int start;
  final int end;
}
