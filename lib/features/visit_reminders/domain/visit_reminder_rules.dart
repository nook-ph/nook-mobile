import 'package:equatable/equatable.dart';
import 'package:nook/core/cafe/domain/cafe_open_status.dart';

/// The timing rules for the one notification Nook sends after a likely
/// visit (a Directions tap), and for the in-app ask that comes before the
/// system permission dialog. Pure: every function takes the time it should
/// treat as "now", so tests can pass any clock.
///
/// All times are the phone's local time ([DateTime] without `isUtc`).
abstract final class VisitReminderRules {
  /// How long after a Directions tap the reminder goes out.
  static const delay = Duration(minutes: 90);

  /// Reminders are only delivered from 09:00 to before 21:00, local.
  static const windowStartHour = 9;
  static const windowEndHour = 21;

  /// A reminder that would land outside the window moves to this hour.
  static const deferHour = 10;

  /// A reminder more than this long after the tap is dropped: by then the
  /// visit is too far back to ask about.
  static const maxAfterTap = Duration(hours: 18);

  /// The in-app ask: at most this many times ever, this far apart.
  static const maxPrePrompts = 3;
  static const prePromptGap = Duration(days: 7);

  /// Two "Didn't go" in a row for one cafe pause its reminders this long.
  static const missesToPause = 2;
  static const missPause = Duration(days: 30);

  /// The share of installs that never get the in-app ask, to compare
  /// against (see [holdoutArm]).
  static const holdoutPercent = 10;

  static bool inWindow(DateTime t) =>
      t.hour >= windowStartHour && t.hour < windowEndHour;

  /// When to deliver a reminder for a Directions tap at [tappedAt], or null
  /// when it should not be sent at all. [delayOverride] is for debug builds
  /// only (see `debugVisitReminderDelay`).
  static DateTime? deliveryTime(DateTime tappedAt, {Duration? delayOverride}) {
    final candidate = tappedAt.add(delayOverride ?? delay);
    if (inWindow(candidate)) return candidate;
    // Before 09:00 waits for 10:00 the same day; 21:00 or later waits for
    // 10:00 the next day.
    var deferred = DateTime(
      candidate.year,
      candidate.month,
      candidate.day,
      deferHour,
    );
    if (candidate.hour >= windowEndHour) {
      deferred = DateTime(
        candidate.year,
        candidate.month,
        candidate.day + 1,
        deferHour,
      );
    }
    if (deferred.difference(tappedAt) > maxAfterTap) return null;
    return deferred;
  }

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// When the 90 minutes start for a tap at [tappedAt] to a cafe in state
  /// [open], or null when the visit can't happen in time: a cafe closed at
  /// the tap counts from its opening, but only if it opens before the
  /// reminder would have gone out from the tap itself. A cafe with no
  /// readable hours is not held against it.
  static DateTime? visitStart(
    DateTime tappedAt,
    CafeOpenAtTap open, {
    Duration? delayOverride,
  }) {
    if (open.isOpen || !open.known) return tappedAt;
    final opensAt = open.opensAt;
    if (opensAt == null) return null;
    final straight = tappedAt.add(delayOverride ?? delay);
    return opensAt.isBefore(straight) ? opensAt : null;
  }

  /// What to do with a Directions tap to [cafeId] at [now], given the
  /// reminders already scheduled ([pending]) and the day a reminder last
  /// went out ([lastDeliveredDay]).
  ///
  /// - Nothing while the cafe's reminders are paused ([pausedUntil]).
  /// - Nothing for a cafe closed at the tap that doesn't open before the
  ///   reminder would go out; one that does counts from its opening.
  /// - At most one pending reminder per cafe: a second tap reschedules.
  /// - At most one reminder a day: a reminder for another cafe on the same
  ///   day is replaced (the newer tap is the likelier visit); a day that
  ///   already had one delivered gets no second.
  static ReminderPlan plan({
    required String cafeId,
    required DateTime now,
    required List<PendingVisitReminder> pending,
    CafeOpenAtTap open = CafeOpenAtTap.unknown,
    DateTime? lastDeliveredDay,
    DateTime? pausedUntil,
    Duration? delayOverride,
  }) {
    if (pausedUntil != null && now.isBefore(pausedUntil)) {
      return const ReminderPlan.skip(ReminderSkipReason.paused);
    }
    final start = visitStart(now, open, delayOverride: delayOverride);
    if (start == null) {
      return const ReminderPlan.skip(ReminderSkipReason.closed);
    }
    final fireAt = deliveryTime(start, delayOverride: delayOverride);
    if (fireAt == null) {
      return const ReminderPlan.skip(ReminderSkipReason.outsideWindow);
    }
    final delivered = lastDeliveredDay;
    if (delivered != null && sameDay(delivered, fireAt)) {
      return const ReminderPlan.skip(ReminderSkipReason.dailyCap);
    }
    final replace = [
      for (final p in pending)
        if (p.cafeId == cafeId || sameDay(p.fireAt, fireAt)) p,
    ];
    return ReminderPlan.schedule(fireAt, replace: replace);
  }

  /// Splits [pending] at [now] into the ones still to come and the latest
  /// delivery day among the ones that have gone out.
  static ({List<PendingVisitReminder> upcoming, DateTime? lastDelivered}) sweep(
    List<PendingVisitReminder> pending,
    DateTime now,
    DateTime? last,
  ) {
    final upcoming = <PendingVisitReminder>[];
    var latest = last;
    for (final p in pending) {
      if (p.fireAt.isAfter(now)) {
        upcoming.add(p);
      } else if (latest == null || p.fireAt.isAfter(latest)) {
        latest = p.fireAt;
      }
    }
    return (upcoming: upcoming, lastDelivered: latest);
  }

  /// Why the in-app ask may not be shown at [now], or null when it may.
  /// Never when permission is already granted or permanently refused, never
  /// after the person turned visit reminders off in Settings, never in the
  /// holdout, at most [maxPrePrompts] times, and at least [prePromptGap]
  /// apart.
  static PrePromptSkipReason? prePromptBlock({
    required DateTime now,
    required List<DateTime> shownAt,
    required NotificationPermission permission,
    required bool remindersEnabled,
    bool holdout = false,
  }) {
    if (!remindersEnabled) return PrePromptSkipReason.disabled;
    if (permission == NotificationPermission.granted) {
      return PrePromptSkipReason.granted;
    }
    if (permission == NotificationPermission.blocked) {
      return PrePromptSkipReason.blocked;
    }
    if (holdout) return PrePromptSkipReason.holdout;
    if (shownAt.length >= maxPrePrompts) return PrePromptSkipReason.cap;
    if (shownAt.isEmpty) return null;
    final last = shownAt.reduce((a, b) => a.isAfter(b) ? a : b);
    return now.difference(last) >= prePromptGap
        ? null
        : PrePromptSkipReason.gap;
  }

  /// [misses] "Didn't go" in a row for a cafe, after one more at [at]: the
  /// new count, and the end of a pause when this one reached
  /// [missesToPause] (the count then starts over).
  static ({int misses, DateTime? pausedUntil}) afterDidntGo(
    int misses,
    DateTime at,
  ) {
    final next = misses + 1;
    if (next >= missesToPause) {
      return (misses: 0, pausedUntil: at.add(missPause));
    }
    return (misses: next, pausedUntil: null);
  }

  /// Whether an install is in the holdout that never gets the ask: a
  /// stable bucket from its [installId], so it never changes arms.
  static HoldoutArm holdoutArm(String installId) =>
      visitReminderIdFor(installId) % 100 < holdoutPercent
      ? HoldoutArm.holdout
      : HoldoutArm.ask;

  /// Whether the OS permission can still be asked for, from what is known:
  /// [enabled] (the OS says notifications are on), how many times the system
  /// dialog was asked for, whether it was ever granted, and whether the last
  /// ask came back at once (no dialog was shown).
  ///
  /// Android 13+ stops showing the dialog after two refusals, and a
  /// permission turned off in system settings is fixed too. iOS shows it
  /// once. Neither says so directly, hence the counting.
  static NotificationPermission permissionFrom({
    required bool enabled,
    required bool isIOS,
    required int systemAsks,
    required bool everGranted,
    required bool lastAskInstant,
  }) {
    if (enabled) return NotificationPermission.granted;
    final blocked =
        everGranted || lastAskInstant || systemAsks >= (isIOS ? 1 : 2);
    return blocked
        ? NotificationPermission.blocked
        : NotificationPermission.notAsked;
  }
}

/// Where the OS notification permission stands, as Nook can tell.
enum NotificationPermission {
  granted('granted'),

  /// Not granted, and the system dialog can still be shown.
  notAsked('not_asked'),

  /// Refused for good, or the reminders channel muted: only the system
  /// settings can turn it on.
  blocked('blocked');

  const NotificationPermission(this.wire);

  /// The `permission` property on analytics events.
  final String wire;
}

/// Whether a cafe was open when Directions was tapped, from its weekly
/// hours: open, closed until [opensAt], closed with no opening ahead, or not
/// [known] (no readable hours).
class CafeOpenAtTap extends Equatable {
  const CafeOpenAtTap.open() : isOpen = true, known = true, opensAt = null;
  const CafeOpenAtTap.closed({this.opensAt}) : isOpen = false, known = true;
  const CafeOpenAtTap._unknown()
    : isOpen = false,
      known = false,
      opensAt = null;

  static const unknown = CafeOpenAtTap._unknown();

  /// Read from a cafe's `operating_hours` at [now], by the same resolver
  /// the cafe page and the cards use (Manila wall-clock hours).
  factory CafeOpenAtTap.fromHours(
    Map<String, dynamic>? operatingHours,
    DateTime now,
  ) {
    final status = CafeOpenStatus.resolve(operatingHours, now: now);
    if (status.isOpen) return const CafeOpenAtTap.open();
    if (status.state == CafeOpenState.unknown) return unknown;
    final next = status.nextOpening;
    return CafeOpenAtTap.closed(
      opensAt: next == null
          ? null
          : now.add(Duration(minutes: next.minutesFromNow)),
    );
  }

  final bool isOpen;
  final bool known;
  final DateTime? opensAt;

  /// The `cafe_open` property on analytics events.
  String get wire => !known
      ? 'unknown'
      : isOpen
      ? 'open'
      : opensAt == null
      ? 'closed'
      : 'opens_later';

  @override
  List<Object?> get props => [isOpen, known, opensAt];
}

enum ReminderSkipReason {
  outsideWindow('outside_window'),
  dailyCap('daily_cap'),
  closed('closed'),
  paused('paused'),
  alreadyBeen('already_been'),
  disabled('disabled'),
  noPermission('no_permission');

  const ReminderSkipReason(this.wire);

  /// The `reason` property on analytics events.
  final String wire;
}

/// Why a Directions tap did not show the in-app ask.
enum PrePromptSkipReason {
  /// Visit reminders are off in Settings.
  disabled('disabled'),

  /// Permission is already granted: nothing to ask (the reminder is set).
  granted('granted'),

  /// Refused for good, or muted in the phone's settings.
  blocked('blocked'),

  /// This install is in the holdout.
  holdout('holdout'),

  /// Asked [VisitReminderRules.maxPrePrompts] times already.
  cap('cap'),

  /// Asked less than [VisitReminderRules.prePromptGap] ago.
  gap('gap'),

  /// Another sheet already showed this session (`SessionAskBudget`).
  sessionBudget('session_budget');

  const PrePromptSkipReason(this.wire);

  final String wire;
}

enum HoldoutArm {
  ask('ask'),
  holdout('holdout');

  const HoldoutArm(this.wire);

  final String wire;
}

/// [VisitReminderRules.plan]'s answer: schedule at [fireAt] after cancelling
/// [replace], or skip for [skipReason].
class ReminderPlan extends Equatable {
  const ReminderPlan.schedule(DateTime this.fireAt, {this.replace = const []})
    : skipReason = null;

  const ReminderPlan.skip(ReminderSkipReason this.skipReason)
    : fireAt = null,
      replace = const [];

  final DateTime? fireAt;
  final List<PendingVisitReminder> replace;
  final ReminderSkipReason? skipReason;

  @override
  List<Object?> get props => [fireAt, replace, skipReason];
}

/// A reminder the OS is holding for later.
class PendingVisitReminder extends Equatable {
  const PendingVisitReminder({
    required this.id,
    required this.cafeId,
    required this.cafeName,
    required this.fireAt,
  });

  /// The OS notification id.
  final int id;
  final String cafeId;
  final String cafeName;
  final DateTime fireAt;

  Map<String, Object> toJson() => {
    'id': id,
    'cafe_id': cafeId,
    'cafe_name': cafeName,
    'fire_at': fireAt.millisecondsSinceEpoch,
  };

  static PendingVisitReminder? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final cafeId = json['cafe_id'];
    final name = json['cafe_name'];
    final fireAt = json['fire_at'];
    if (id is! int || cafeId is! String || fireAt is! int) return null;
    return PendingVisitReminder(
      id: id,
      cafeId: cafeId,
      cafeName: name is String ? name : '',
      fireAt: DateTime.fromMillisecondsSinceEpoch(fireAt),
    );
  }

  @override
  List<Object?> get props => [id, cafeId, cafeName, fireAt];
}

/// A stable notification id for [cafeId] (FNV-1a, 31 bits), so the same
/// cafe always maps to the same OS notification and a reschedule replaces
/// it. Dart's `String.hashCode` is not promised to be stable across runs.
int visitReminderIdFor(String cafeId) {
  var hash = 0x811c9dc5;
  for (final unit in cafeId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  // Keep clear of 0 and fit a Java int.
  return (hash & 0x7FFFFFFF) | 1;
}
