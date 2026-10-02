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

/// The next time a closed cafe opens.
class CafeNextOpening {
  const CafeNextOpening({
    required this.dayOffset,
    required this.dayKey,
    required this.openMinutes,
    required this.minutesFromNow,
  });

  /// 0 for later today, 1 for tomorrow, up to 7 (this weekday next week).
  final int dayOffset;

  /// The `operating_hours` key of the day it opens, e.g. `monday`.
  final String dayKey;

  /// Opening time in minutes from that day's midnight.
  final int openMinutes;

  final int minutesFromNow;
}

class CafeOpenStatus {
  const CafeOpenStatus._(
    this.state,
    this.minutesUntilClose, {
    this.closesAtMinutes,
    this.nextOpening,
  });

  final CafeOpenState state;

  /// Minutes remaining until the cafe closes; null unless [state] is
  /// [CafeOpenState.open] or [CafeOpenState.closingSoon], and null for a cafe
  /// whose hours run round the clock all week, which never closes.
  final int? minutesUntilClose;

  /// The closing time as a clock time, in minutes from midnight (0 for a
  /// midnight close). Null unless the cafe is open.
  final int? closesAtMinutes;

  /// When the cafe next opens. Null while it is open, and when no readable
  /// day in the coming week opens.
  final CafeNextOpening? nextOpening;

  static const CafeOpenStatus unknown = CafeOpenStatus._(
    CafeOpenState.unknown,
    null,
  );
  static const CafeOpenStatus closed = CafeOpenStatus._(
    CafeOpenState.closed,
    null,
  );

  /// One threshold for every surface, so a card and the details page never
  /// disagree about whether a cafe is about to close.
  static const Duration closingSoonThreshold = Duration(minutes: 30);

  bool get isOpen =>
      state == CafeOpenState.open || state == CafeOpenState.closingSoon;

  /// [now] (default: this instant) as Manila wall-clock time. The result is a
  /// UTC-flagged `DateTime` whose fields read as the time on a clock in the
  /// Philippines; use it for the weekday and the hour, not as an instant.
  static DateTime manilaNow([DateTime? now]) =>
      (now ?? DateTime.now()).toUtc().add(_manilaOffset);

  /// Opening and closing minutes for [dayKey] (`monday`..`sunday`), read by
  /// the same rules as [resolve]. Null for a rest day, and for hours that are
  /// missing, malformed or a `00:00`-`00:00` placeholder.
  static ({int open, int close})? hoursFor(
    Map<String, dynamic>? operatingHours,
    String dayKey,
  ) {
    final parsed = _DayHours.parse(operatingHours?[dayKey]);
    final open = parsed?.openMinutes;
    final close = parsed?.closeMinutes;
    if (open == null || close == null) return null;
    return (open: open, close: close);
  }

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

    final manilaNow = CafeOpenStatus.manilaNow(now);
    final nowMinutes = manilaNow.hour * 60 + manilaNow.minute;

    // The parsed hours `offset` days from today (-1 is yesterday).
    _DayHours? dayAt(int offset) => _DayHours.parse(
      operatingHours[_dayKeys[(manilaNow.weekday - 1 + offset) % 7]],
    );

    final today = dayAt(0);
    final yesterday = dayAt(-1);

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
        // A span that ends on the stroke of midnight carries straight on when
        // the next day opens at 00:00 ("14:00-24:00" then "00:00-02:00"): the
        // cafe closes when that one does. A whole week of them never closes.
        var end = span.end;
        var roundTheClock = false;
        while (end % _minutesPerDay == 0) {
          final dayOffset = end ~/ _minutesPerDay;
          if (dayOffset > 7) {
            roundTheClock = true;
            break;
          }
          final next = dayAt(dayOffset)?.spanFrom(end);
          if (next == null || next.start != end) break;
          end = next.end;
        }

        if (roundTheClock) {
          return CafeOpenStatus._(
            CafeOpenState.open,
            null,
            closesAtMinutes: span.end % _minutesPerDay,
          );
        }
        final remaining = end - nowMinutes;
        return CafeOpenStatus._(
          remaining <= closingSoonThreshold.inMinutes
              ? CafeOpenState.closingSoon
              : CafeOpenState.open,
          remaining,
          closesAtMinutes: end % _minutesPerDay,
        );
      }
    }

    // The first opening still ahead: later today, else the next day that
    // opens. Rest days and unreadable days are skipped, never guessed at.
    CafeNextOpening? nextOpening;
    for (var offset = 0; offset <= 7; offset++) {
      final open = dayAt(offset)?.openMinutes;
      if (open == null) continue;
      final minutesFromNow = offset * _minutesPerDay + open - nowMinutes;
      if (minutesFromNow <= 0) continue;
      nextOpening = CafeNextOpening(
        dayOffset: offset,
        dayKey: _dayKeys[(manilaNow.weekday - 1 + offset) % 7],
        openMinutes: open,
        minutesFromNow: minutesFromNow,
      );
      break;
    }

    // Nothing covers now. Only claim "closed" when today's entry was actually
    // readable — otherwise we are reporting our own missing data as a fact
    // about the cafe.
    return CafeOpenStatus._(
      today == null ? CafeOpenState.unknown : CafeOpenState.closed,
      null,
      nextOpening: nextOpening,
    );
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
