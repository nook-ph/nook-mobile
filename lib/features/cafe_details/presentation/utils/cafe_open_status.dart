import 'package:nook/core/cafe/domain/cafe_open_status.dart' as core;

/// Whether a cafe is open right now, worked out from its weekly hours.
///
/// One source for the header line, the hours row and the pinned bar, so the
/// three can never disagree. Pure: pass [now] in tests.
///
/// Open or closed, how the hours are read and the Manila clock all come from
/// the core resolver the map and search cards use, so the details page and a
/// card cannot disagree either. This class only adds the page's wording.
class CafeOpenStatus {
  const CafeOpenStatus._({
    required this.hasAnyHours,
    required this.isOpen,
    this.openMinutes,
    this.closeMinutes,
    this.minutesUntilChange,
    this.opensDayOffset = 0,
    this.opensDayKey,
  });

  /// How close the next change has to be before the status turns amber
  /// ("Opens soon", "Closes soon").
  static final soonThreshold =
      core.CafeOpenStatus.closingSoonThreshold.inMinutes;

  /// False when no day of the week has both an opening and a closing time.
  /// The page then makes no open-or-closed claim at all.
  final bool hasAnyHours;
  final bool isOpen;

  /// When closed, the next opening time in minutes from midnight: today's
  /// while it is still ahead, otherwise the next day that opens. Null when
  /// open, and when today has no hours.
  final int? openMinutes;

  /// When open, the time it closes in minutes from midnight, which is past
  /// midnight for overnight hours. Null when closed.
  final int? closeMinutes;

  /// How many days ahead [openMinutes] is: 0 today, 1 tomorrow.
  final int opensDayOffset;

  /// The `operating_hours` key of the day [openMinutes] is on.
  final String? opensDayKey;

  /// Minutes until the cafe next opens (when closed) or closes (when open).
  /// Null when today has no hours, when the next opening is on a later day
  /// and not soon, and for round-the-clock hours.
  final int? minutesUntilChange;

  /// Closed, but today's opening is at most [soonThreshold] minutes away.
  bool get opensSoon =>
      !isOpen &&
      minutesUntilChange != null &&
      minutesUntilChange! <= soonThreshold;

  /// Open, but closing is at most [soonThreshold] minutes away.
  bool get closesSoon =>
      isOpen &&
      minutesUntilChange != null &&
      minutesUntilChange! <= soonThreshold;

  /// Either of the amber states.
  bool get isSoon => opensSoon || closesSoon;

  static const orderedDays = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
  ];

  /// The `operating_hours` key for [date]'s weekday.
  static String dayKey(DateTime date) => orderedDays[date.weekday % 7];

  /// Today's key where the cafes are. Hours are Manila wall-clock times, so
  /// "today" is Manila's day, whatever zone the phone is set to.
  static String todayKey([DateTime? now]) =>
      dayKey(core.CafeOpenStatus.manilaNow(now));

  /// [now] is an instant; it is read on the Manila clock, so a local or a
  /// UTC `DateTime` for the same moment gives the same answer.
  static CafeOpenStatus resolve(
    Map<String, dynamic> operatingHours,
    DateTime now,
  ) {
    final hasAnyHours = orderedDays.any(
      (day) => hoursFor(operatingHours, day) != null,
    );
    final status = core.CafeOpenStatus.resolve(operatingHours, now: now);

    if (status.isOpen) {
      return CafeOpenStatus._(
        hasAnyHours: hasAnyHours,
        isOpen: true,
        closeMinutes: status.closesAtMinutes,
        minutesUntilChange: status.minutesUntilClose,
      );
    }

    // A day with no readable hours of its own says nothing about when the
    // cafe opens next.
    final next = status.nextOpening;
    if (next == null || hoursFor(operatingHours, todayKey(now)) == null) {
      return CafeOpenStatus._(hasAnyHours: hasAnyHours, isOpen: false);
    }

    return CafeOpenStatus._(
      hasAnyHours: hasAnyHours,
      isOpen: false,
      openMinutes: next.openMinutes,
      opensDayOffset: next.dayOffset,
      opensDayKey: next.dayKey,
      minutesUntilChange:
          next.dayOffset == 0 || next.minutesFromNow <= soonThreshold
          ? next.minutesFromNow
          : null,
    );
  }

  /// Opening and closing minutes for [day], or null when that day is closed
  /// or its hours are missing, unreadable or a placeholder. Read by the core
  /// resolver's rules.
  static ({int open, int close})? hoursFor(
    Map<String, dynamic> operatingHours,
    String day,
  ) => core.CafeOpenStatus.hoursFor(operatingHours, day);

  /// "10:00 PM".
  static String formatTime(int minutes) {
    final hour24 = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  /// "10 PM" on the hour, "9:30 PM" otherwise. For the one-line status where
  /// width is short.
  static String formatTimeShort(int minutes) {
    final hour24 = (minutes ~/ 60) % 24;
    final minute = minutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    if (minute == 0) return '$hour12 $period';
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  /// "7:00 AM – 10:00 PM", or "Closed" for a day without hours.
  static String formatRange(Map<String, dynamic> operatingHours, String day) {
    final hours = hoursFor(operatingHours, day);
    if (hours == null) return 'Closed';
    return '${formatTime(hours.open)} – ${formatTime(hours.close)}';
  }

  /// "Open", "Closed", "Opens soon" or "Closes soon".
  String get label {
    if (opensSoon) return 'Opens soon';
    if (closesSoon) return 'Closes soon';
    return isOpen ? 'Open' : 'Closed';
  }

  /// " tomorrow" or " Monday" when the next opening is not today, so a time
  /// is never shown for a day the cafe stays shut.
  String get _opensDaySuffix {
    final day = opensDayKey;
    if (opensDayOffset <= 0 || day == null) return '';
    if (opensDayOffset == 1) return ' tomorrow';
    return ' ${day[0].toUpperCase()}${day.substring(1)}';
  }

  /// What follows the label on the header line and in the bar: "until 10 PM"
  /// when open, "opens 7 AM" when closed and today's opening is still ahead,
  /// "opens 7 AM tomorrow" / "opens 7 AM Tuesday" once it has passed. Null
  /// when today has no hours.
  ///
  /// In the amber states it is just the time: "Closes soon 10 PM".
  String? get shortDetail {
    if (opensSoon) return formatTimeShort(openMinutes!);
    if (closesSoon) return formatTimeShort(closeMinutes!);
    if (isOpen) {
      final close = closeMinutes;
      return close == null ? null : 'until ${formatTimeShort(close)}';
    }
    final open = openMinutes;
    return open == null
        ? null
        : 'opens ${formatTimeShort(open)}$_opensDaySuffix';
  }

  /// What follows the label on the hours row: "Closes 10:00 PM" or
  /// "Opens 7:00 AM". Null when today has no hours.
  ///
  /// In the amber states: "10:00 PM, in 25 min".
  String? get rowDetail {
    if (opensSoon) {
      return '${formatTime(openMinutes!)}, in $minutesUntilChange min';
    }
    if (closesSoon) {
      return '${formatTime(closeMinutes!)}, in $minutesUntilChange min';
    }
    if (isOpen) {
      final close = closeMinutes;
      return close == null ? null : 'Closes ${formatTime(close)}';
    }
    final open = openMinutes;
    return open == null ? null : 'Opens ${formatTime(open)}$_opensDaySuffix';
  }

  /// The one line in the pinned bar: "Open until 10 PM", "Closed · opens
  /// 7 AM", "Opens 7 AM · in 20 min" or "Closes 10 PM · in 25 min".
  String get barText {
    if (opensSoon) {
      return 'Opens ${formatTimeShort(openMinutes!)} · in $minutesUntilChange min';
    }
    if (closesSoon) {
      return 'Closes ${formatTimeShort(closeMinutes!)} · in $minutesUntilChange min';
    }
    final detail = shortDetail;
    if (isOpen) return detail == null ? 'Open' : 'Open $detail';
    return detail == null ? 'Closed' : 'Closed · $detail';
  }
}
