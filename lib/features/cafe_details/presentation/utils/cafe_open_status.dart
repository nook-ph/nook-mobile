/// Whether a cafe is open right now, worked out from its weekly hours.
///
/// One source for the header line, the hours row and the pinned bar, so the
/// three can never disagree. Pure: pass [now] in tests.
class CafeOpenStatus {
  const CafeOpenStatus._({
    required this.hasAnyHours,
    required this.isOpen,
    this.openMinutes,
    this.closeMinutes,
    this.minutesUntilChange,
  });

  /// How close the next change has to be before the status turns amber
  /// ("Opens soon", "Closes soon").
  static const soonThreshold = 30;

  /// False when no day of the week has both an opening and a closing time.
  /// The page then makes no open-or-closed claim at all.
  final bool hasAnyHours;
  final bool isOpen;

  /// Today's opening and closing time in minutes from midnight; null when
  /// today has no hours.
  final int? openMinutes;
  final int? closeMinutes;

  /// Minutes until the cafe next opens (when closed) or closes (when open),
  /// counted within today's hours only. Null when today has no hours or
  /// today's opening has already passed.
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

  static CafeOpenStatus resolve(
    Map<String, dynamic> operatingHours,
    DateTime now,
  ) {
    final hasAnyHours = orderedDays.any(
      (day) => hoursFor(operatingHours, day) != null,
    );
    final today = hoursFor(operatingHours, dayKey(now));
    if (today == null) {
      return CafeOpenStatus._(hasAnyHours: hasAnyHours, isOpen: false);
    }

    final nowMinutes = now.hour * 60 + now.minute;
    // A closing time at or before the opening time runs past midnight.
    final overnight = today.close <= today.open;
    final isOpen = overnight
        ? (nowMinutes >= today.open || nowMinutes < today.close)
        : (nowMinutes >= today.open && nowMinutes < today.close);

    int? untilChange;
    // Opening and closing at the same minute is round the clock: it never
    // "closes soon".
    final allDay = today.open == today.close;
    if (isOpen && !allDay) {
      untilChange = today.close - nowMinutes;
      // Past midnight the close is tomorrow's clock time.
      if (untilChange <= 0) untilChange += 24 * 60;
    } else if (today.open > nowMinutes) {
      untilChange = today.open - nowMinutes;
    }

    return CafeOpenStatus._(
      hasAnyHours: hasAnyHours,
      isOpen: isOpen,
      openMinutes: today.open,
      closeMinutes: today.close,
      minutesUntilChange: untilChange,
    );
  }

  /// Opening and closing minutes for [day], or null when that day is closed
  /// or its hours are missing or unreadable.
  static ({int open, int close})? hoursFor(
    Map<String, dynamic> operatingHours,
    String day,
  ) {
    final raw = operatingHours[day];
    if (raw is! Map) return null;
    final open = _parseMinutes(raw['open']?.toString());
    final close = _parseMinutes(raw['close']?.toString());
    if (open == null || close == null) return null;
    return (open: open, close: close);
  }

  static int? _parseMinutes(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

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

  /// What follows the label on the header line and in the bar: "until 10 PM"
  /// when open, "opens 7 AM" when closed and today's opening is still ahead
  /// or known. Null when today has no hours.
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
    return open == null ? null : 'opens ${formatTimeShort(open)}';
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
    return open == null ? null : 'Opens ${formatTime(open)}';
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
