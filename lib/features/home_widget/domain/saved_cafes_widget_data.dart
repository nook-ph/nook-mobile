import 'package:equatable/equatable.dart';
import 'package:nook/core/cafe/domain/cafe_open_status.dart';
import 'package:nook/core/presentation/widgets/cafe_distance_label.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_open_status.dart'
    as details;

/// A Want to try cafe as the home-screen widget needs it.
class WidgetCafe extends Equatable {
  const WidgetCafe({
    required this.id,
    required this.name,
    this.operatingHours,
    this.distanceMeters,
  });

  final String id;
  final String name;

  /// Raw `cafes.operating_hours`.
  final Map<String, dynamic>? operatingHours;

  /// From the last position the app already had; null without one. The
  /// widget never asks for a position itself.
  final double? distanceMeters;

  @override
  List<Object?> get props => [id, name, operatingHours, distanceMeters];
}

/// How a row's status reads, so the widget can colour its dot. The words
/// always carry the meaning on their own.
enum WidgetRowTone { open, closingSoon, closed, unknown }

/// One row of the widget: a cafe and its status line at a moment.
class WidgetRow extends Equatable {
  const WidgetRow({
    required this.cafeId,
    required this.line,
    required this.tone,
  });

  final String cafeId;

  /// "Open until 9 PM · 1.2 km", "Opens 8 AM tomorrow".
  final String line;
  final WidgetRowTone tone;

  List<Object> toJson() => [cafeId, line, tone.name];

  @override
  List<Object?> get props => [cafeId, line, tone];
}

/// What the widget shows from [at] until the next frame.
class WidgetFrame extends Equatable {
  const WidgetFrame({
    required this.at,
    required this.rows,
    required this.openCount,
  });

  final DateTime at;

  /// At most [SavedCafesWidgetData.maxRows], best first.
  final List<WidgetRow> rows;

  /// How many of all the saved cafes are open at [at].
  final int openCount;

  Map<String, Object> toJson() => {
    't': at.millisecondsSinceEpoch,
    'o': openCount,
    'rows': [for (final r in rows) r.toJson()],
  };

  /// Same content, whatever the time.
  bool sameAs(WidgetFrame other) =>
      openCount == other.openCount && _listEquals(rows, other.rows);

  @override
  List<Object?> get props => [at, rows, openCount];
}

/// Everything the home-screen widget draws, worked out ahead of time.
///
/// The widget cannot run Dart, and "open now" changes while the app is
/// closed. So the app lays out the coming week as frames: one at every
/// moment any saved cafe opens, starts closing soon or closes, and at every
/// Manila midnight (when "tomorrow" becomes "today"). The widget shows the
/// last frame that has started, and an update is scheduled for each frame
/// so it turns over on time. Past [until] it says to open Nook instead of
/// showing hours that may no longer be true.
class SavedCafesWidgetData extends Equatable {
  const SavedCafesWidgetData({
    required this.generatedAt,
    required this.until,
    required this.names,
    required this.frames,
  });

  /// Where the app writes [toJson] for the widget
  /// (`SavedCafesWidgetProvider.DATA_KEY`).
  static const storageKey = 'saved_cafes_v1';

  /// The medium widget's rows; the small one shows the first.
  static const maxRows = 3;

  /// How far ahead frames are laid out.
  static const horizon = Duration(days: 7);

  /// Saved cafes considered, newest first. Keeps the payload small for
  /// someone with a long list; the widget shows three.
  static const maxCafes = 30;

  /// How long after the write a distance is still worth showing. The
  /// position is the one the app had when it wrote; a few hours on, the
  /// person may be across town, so later frames drop the km and order open
  /// cafes newest saved first instead of nearest first.
  static const distanceFreshFor = Duration(hours: 3);

  final DateTime generatedAt;
  final DateTime until;

  /// cafe id → name, for every cafe in any frame.
  final Map<String, String> names;
  final List<WidgetFrame> frames;

  bool get isEmpty => names.isEmpty;

  /// The times after the first frame at which the widget should redraw.
  List<DateTime> get updateTimes => [
    for (final f in frames.skip(1)) f.at,
    until,
  ];

  /// The next moment after [now] when the widget must redraw: the next
  /// frame's start, else [until] (when it turns to "Open Nook"), else null.
  ///
  /// `SavedCafesWidgetProvider.nextTurnover` does the same from the JSON
  /// each time it draws, and arms one alarm for it with a 10-minute window
  /// (`AlarmManager.setWindow`, no exact-alarm permission), so the widget
  /// keeps itself on time with or without the app.
  DateTime? nextUpdateAfter(DateTime now) {
    for (final t in updateTimes) {
      if (t.isAfter(now)) return t;
    }
    return null;
  }

  /// [cafes] are the Want to try list, newest first.
  factory SavedCafesWidgetData.build(
    List<WidgetCafe> cafes, {
    required DateTime now,
  }) {
    final considered = _dedupe(cafes).take(maxCafes).toList();
    final start = _floorToMinute(now.toUtc());
    final until = start.add(horizon);

    final times = <DateTime>{start};
    for (final cafe in considered) {
      times.addAll(_transitions(cafe.operatingHours, start, until));
    }
    times.addAll(_manilaMidnights(start, until));
    final distancesUntil = start.add(distanceFreshFor);
    if (considered.any((c) => c.distanceMeters != null)) {
      // A frame where the km come off, even if no cafe changes then.
      times.add(distancesUntil);
    }
    final sorted =
        times.where((t) => !t.isBefore(start) && t.isBefore(until)).toList()
          ..sort();

    final frames = <WidgetFrame>[];
    for (final t in sorted) {
      final frame = frameAt(
        considered,
        t,
        withDistances: t.isBefore(distancesUntil),
      );
      if (frames.isNotEmpty && frames.last.sameAs(frame)) continue;
      frames.add(frame);
    }

    final shown = {
      for (final f in frames)
        for (final r in f.rows) r.cafeId,
    };
    return SavedCafesWidgetData(
      generatedAt: start,
      until: until,
      names: {
        for (final c in considered)
          if (shown.contains(c.id)) c.id: c.name,
      },
      frames: frames,
    );
  }

  /// The rows at [at]: open cafes first (nearest first when distances are
  /// known, else newest saved), then closed ones by how soon they open,
  /// then those whose hours we do not know. [cafes] newest first.
  /// Without [withDistances] the km are ignored: no suffix, no nearest
  /// first.
  static WidgetFrame frameAt(
    List<WidgetCafe> cafes,
    DateTime at, {
    bool withDistances = true,
  }) {
    final entries = <_Entry>[];
    for (var i = 0; i < cafes.length; i++) {
      final cafe = cafes[i];
      entries.add(
        _Entry(
          index: i,
          cafe: cafe,
          distance: withDistances ? cafe.distanceMeters : null,
          status: CafeOpenStatus.resolve(cafe.operatingHours, now: at),
        ),
      );
    }
    entries.sort(_compare);
    return WidgetFrame(
      at: at,
      openCount: entries.where((e) => e.status.isOpen).length,
      rows: [
        for (final e in entries.take(maxRows))
          WidgetRow(
            cafeId: e.cafe.id,
            line: lineFor(e.status, e.distance),
            tone: _tone(e.status.state),
          ),
      ],
    );
  }

  /// "Open until 9 PM", "Closes soon · 9:30 PM", "Opens 8 AM tomorrow",
  /// with " · 1.2 km" when the distance is known.
  static String lineFor(CafeOpenStatus status, double? distanceMeters) {
    // A no-break space keeps "2.7 km" on one line in the narrow widget.
    final distance = distanceMeters == null
        ? null
        : formatDistanceMeters(distanceMeters)?.replaceAll(' ', '\u00A0');
    final text = _statusText(status);
    return distance == null ? text : '$text · $distance';
  }

  static String _statusText(CafeOpenStatus status) {
    final time = details.CafeOpenStatus.formatTimeShort;
    switch (status.state) {
      case CafeOpenState.open:
        final close = status.closesAtMinutes;
        if (status.minutesUntilClose == null || close == null) {
          return 'Open 24 hours';
        }
        return 'Open until ${time(close)}';
      case CafeOpenState.closingSoon:
        return 'Closes soon · ${time(status.closesAtMinutes ?? 0)}';
      case CafeOpenState.closed:
      case CafeOpenState.unknown:
        final next = status.nextOpening;
        if (next != null) {
          final opens = 'Opens ${time(next.openMinutes)}';
          if (next.dayOffset == 0) return opens;
          if (next.dayOffset == 1) return '$opens tomorrow';
          final day = next.dayKey;
          return '$opens ${day[0].toUpperCase()}${day.substring(1)}';
        }
        return status.state == CafeOpenState.closed
            ? 'Closed'
            : 'Hours not listed';
    }
  }

  static WidgetRowTone _tone(CafeOpenState state) => switch (state) {
    CafeOpenState.open => WidgetRowTone.open,
    CafeOpenState.closingSoon => WidgetRowTone.closingSoon,
    CafeOpenState.closed => WidgetRowTone.closed,
    CafeOpenState.unknown => WidgetRowTone.unknown,
  };

  static int _rank(CafeOpenStatus s) {
    if (s.isOpen) return 0;
    if (s.nextOpening != null) return 1;
    return 2;
  }

  static int _compare(_Entry a, _Entry b) {
    final rank = _rank(a.status).compareTo(_rank(b.status));
    if (rank != 0) return rank;
    if (a.status.isOpen) {
      final da = a.distance;
      final db = b.distance;
      if (da != null && db != null && da != db) return da.compareTo(db);
      if (da != null && db == null) return -1;
      if (da == null && db != null) return 1;
    } else {
      final na = a.status.nextOpening?.minutesFromNow;
      final nb = b.status.nextOpening?.minutesFromNow;
      if (na != null && nb != null && na != nb) return na.compareTo(nb);
    }
    return a.index.compareTo(b.index);
  }

  Map<String, Object> toJson() => {
    'v': 1,
    'generated': generatedAt.millisecondsSinceEpoch,
    'until': until.millisecondsSinceEpoch,
    'names': names,
    'frames': [for (final f in frames) f.toJson()],
  };

  @override
  List<Object?> get props => [generatedAt, until, names, frames];
}

class _Entry {
  const _Entry({
    required this.index,
    required this.cafe,
    required this.distance,
    required this.status,
  });

  final int index;
  final WidgetCafe cafe;

  /// The cafe's distance if this frame still uses it.
  final double? distance;
  final CafeOpenStatus status;
}

const _manilaOffset = Duration(hours: 8);
const _dayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

Iterable<WidgetCafe> _dedupe(List<WidgetCafe> cafes) sync* {
  final seen = <String>{};
  for (final c in cafes) {
    if (c.id.isEmpty || !seen.add(c.id)) continue;
    yield c;
  }
}

DateTime _floorToMinute(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day, t.hour, t.minute);

/// The instant of Manila midnight starting the Manila day [offset] days
/// after [start]'s.
DateTime _manilaMidnight(DateTime start, int offset) {
  final manila = start.add(_manilaOffset);
  return DateTime.utc(
    manila.year,
    manila.month,
    manila.day + offset,
  ).subtract(_manilaOffset);
}

Iterable<DateTime> _manilaMidnights(DateTime start, DateTime until) sync* {
  for (var d = 1; d <= 8; d++) {
    final t = _manilaMidnight(start, d);
    if (t.isBefore(until)) yield t;
  }
}

/// Every instant in `[start - 1 day, until]` where [hours] open, enter the
/// closing-soon window, or close. Over-inclusive is fine: a time where
/// nothing changes produces a frame equal to the one before, which is
/// dropped.
Iterable<DateTime> _transitions(
  Map<String, dynamic>? hours,
  DateTime start,
  DateTime until,
) sync* {
  if (hours == null || hours.isEmpty) return;
  final soon = CafeOpenStatus.closingSoonThreshold;
  final manilaWeekday = start.add(_manilaOffset).weekday;
  for (var d = -1; d <= 8; d++) {
    final dayStart = _manilaMidnight(start, d);
    final key = _dayKeys[(manilaWeekday - 1 + d) % 7];
    final span = CafeOpenStatus.hoursFor(hours, key);
    if (span == null) continue;
    final open = dayStart.add(Duration(minutes: span.open));
    final closeMinutes = span.close > span.open
        ? span.close
        : span.close + 24 * 60;
    final close = dayStart.add(Duration(minutes: closeMinutes));
    for (final t in [open, close.subtract(soon), close]) {
      if (!t.isBefore(start) && t.isBefore(until)) yield t;
    }
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
