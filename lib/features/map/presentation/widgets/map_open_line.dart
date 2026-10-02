import 'package:nook/core/cafe/domain/cafe_open_status.dart';

/// "Open · Closes 10 PM" / "Closed · Opens 7 AM", split into the coloured
/// word and the grey detail. Null when the hours say nothing reliable.
class MapOpenLine {
  const MapOpenLine({required this.isOpen, required this.detail});

  final bool isOpen;

  /// "Closes 10 PM", "Opens 7 AM", or empty when the time is unknown.
  final String detail;

  String get word => isOpen ? 'Open' : 'Closed';

  static const _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  /// Hours are Manila wall-clock times (see [CafeOpenStatus]).
  static MapOpenLine? resolve(Map<String, dynamic>? hours, {DateTime? now}) {
    final status = CafeOpenStatus.resolve(hours, now: now);
    if (status.state == CafeOpenState.unknown || hours == null) return null;

    final manila = (now ?? DateTime.now()).toUtc().add(
      const Duration(hours: 8),
    );
    final nowMinutes = manila.hour * 60 + manila.minute;

    if (status.isOpen) {
      final remaining = status.minutesUntilClose;
      final detail = remaining == null
          ? ''
          : 'Closes ${_clock((nowMinutes + remaining) % (24 * 60))}';
      return MapOpenLine(isOpen: true, detail: detail);
    }

    // The next opening: later today, else the next day that opens.
    for (var offset = 0; offset < 7; offset++) {
      final key = _days[(manila.weekday - 1 + offset) % 7];
      final open = _openMinutes(hours[key]);
      if (open == null) continue;
      if (offset == 0 && open <= nowMinutes) continue;
      final time = _clock(open);
      final when = switch (offset) {
        0 => '',
        1 => ' tomorrow',
        _ => ' ${_capitalise(key)}',
      };
      return MapOpenLine(isOpen: false, detail: 'Opens $time$when');
    }
    return const MapOpenLine(isOpen: false, detail: '');
  }

  static int? _openMinutes(Object? raw) {
    if (raw is! Map) return null;
    if (raw['closed'] == true) return null;
    final open = raw['open']?.toString();
    final close = raw['close']?.toString();
    if (open == null || close == null || open == close) return null;
    final parts = open.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// "10 PM", "7:30 AM".
  static String _clock(int minutes) {
    final h24 = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final period = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return m == 0
        ? '$h12 $period'
        : '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  static String _capitalise(String s) => s[0].toUpperCase() + s.substring(1);
}
