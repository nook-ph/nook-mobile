import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/notification_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/features/visit_reminders/data/local_notifier.dart';
import 'package:nook/features/visit_reminders/data/visit_reminder_store.dart';
import 'package:nook/features/visit_reminders/domain/visit_reminder_rules.dart';

/// Debug builds only: `--dart-define=VISIT_REMINDER_DELAY_SECONDS=30` sends
/// the reminder 30 s after a Directions tap instead of 90 min, to test it.
/// Release builds always use [VisitReminderRules.delay].
Duration? debugVisitReminderDelay() {
  if (!kDebugMode) return null;
  const seconds = int.fromEnvironment('VISIT_REMINDER_DELAY_SECONDS');
  return seconds > 0 ? const Duration(seconds: seconds) : null;
}

/// A reminder asked the app to open a cafe. Every tap but "Didn't go" means
/// "I went": the cafe is marked Been, then rated (signed in) or offered a
/// sign-in to rank it (guest).
class VisitReminderOpen {
  const VisitReminderOpen({required this.cafeId});

  final String cafeId;
}

/// What a Directions tap should do about the reminder, worked out before
/// the maps app opens.
class DirectionsDecision {
  const DirectionsDecision._({this.trip, this.ask = false});

  static const none = DirectionsDecision._();

  /// The reminder that would go out, or null when nothing would be sent.
  final VisitTrip? trip;

  /// Show the in-app ask before opening Maps. Only with a [trip].
  final bool ask;

  /// A reminder is due and permission is already granted: schedule it once
  /// Maps has opened ([VisitReminderService.confirmTrip]).
  bool get scheduleOnLaunch => trip != null && !ask;
}

/// The one notification Nook sends from the phone: "Did you make it to
/// [cafe]?" about 90 minutes after Directions to it. Decides at the tap
/// whether to ask for it and when it would go out, schedules and cancels it,
/// and turns taps on it into [openRequests] for the router.
///
/// App-wide singleton, started once from `main`.
class VisitReminderService {
  VisitReminderService({
    required LocalNotifier notifier,
    required VisitReminderStore store,
    DateTime Function()? now,
    Duration? delayOverride,
    bool? isIOS,
  }) : _notifier = notifier,
       _store = store,
       _now = now ?? DateTime.now,
       _delayOverride = delayOverride,
       _isIOS = isIOS ?? defaultTargetPlatform == TargetPlatform.iOS;

  final LocalNotifier _notifier;
  final VisitReminderStore _store;
  final DateTime Function() _now;
  final Duration? _delayOverride;
  final bool _isIOS;

  static const title = 'Did you make it to {cafe}?';
  static const body = 'Mark it Been in one tap.';

  static String titleFor(String cafeName) => title.replaceFirst(
    '{cafe}',
    cafeName.trim().isEmpty ? 'the cafe' : cafeName.trim(),
  );

  /// A cafe the reminder wants opened. The app's router listens and clears
  /// it once handled; a cold start from a notification sets it before
  /// anything listens, so the listener reads it once on attach.
  final ValueNotifier<VisitReminderOpen?> openRequests = ValueNotifier(null);

  StreamSubscription<CafeStatusState>? _statuses;
  AppLifecycleListener? _lifecycle;
  bool _started = false;

  Future<void> start({CafeStatusCubit? statuses}) async {
    if (_started) return;
    _started = true;
    try {
      await _notifier.init(onTap: _onTap);
      final launch = await _notifier.launchTap();
      if (launch != null) _onTap(launch);
    } catch (e) {
      debugPrint('[VisitReminders] init failed: $e');
    }
    await _catchUp();
    await _resumeTrip();
    unawaited(_logState());
    final cubit = statuses;
    if (cubit != null) {
      _statuses = cubit.stream.listen(_onStatuses);
    }
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_catchUp()));
  }

  void dispose() {
    _statuses?.cancel();
    _lifecycle?.dispose();
    openRequests.dispose();
  }

  /// `notification_state` once per app open, with the holdout arm.
  Future<void> _logState() async {
    try {
      final appEnabled = await _notifier.areEnabled();
      final muted = appEnabled && await _notifier.channelMuted();
      final arm = await holdoutArm();
      logAppEvent(
        NotificationEvents.notificationState,
        properties: {
          'app_enabled': appEnabled,
          'channel_muted': muted,
          'permission': (await permission()).wire,
          'reminders_enabled': await _store.readEnabled(),
          'holdout_arm': arm.wire,
        },
      );
    } catch (e) {
      debugPrint('[VisitReminders] state log failed: $e');
    }
  }

  /// This install's arm of the 10% holdout that never gets the ask. Logged
  /// once, when the install id is first made.
  Future<HoldoutArm> holdoutArm() async {
    final install = await _store.installId();
    final arm = VisitReminderRules.holdoutArm(install.id);
    if (install.created) {
      logAppEvent(
        NotificationEvents.holdoutAssigned,
        properties: {'arm': arm.wire},
      );
    }
    return arm;
  }

  /// Sends what the background isolate queued, counts its "Didn't go", and
  /// forgets reminders that have gone out, noting the day for the
  /// one-a-day rule.
  Future<void> _catchUp() async {
    try {
      await _drainQueue();
      await _sweep();
    } catch (e) {
      debugPrint('[VisitReminders] catch-up failed: $e');
    }
  }

  Future<void> _drainQueue() async {
    for (final event in await _store.takeQueuedEvents()) {
      if (event['event'] != 'didnt_go') continue;
      final cafeId = event['cafe_id'];
      final at = event['at'];
      if (cafeId is! String) continue;
      await _didntGo(
        cafeId,
        at is int ? DateTime.fromMillisecondsSinceEpoch(at) : _now(),
      );
    }
  }

  /// One more "Didn't go" for [cafeId]; the second in a row pauses its
  /// reminders for 30 days. Nothing is shown.
  Future<void> _didntGo(String cafeId, DateTime at) async {
    logAppEvent(
      NotificationEvents.postVisitDidntGo,
      properties: {'cafe_id': cafeId},
    );
    final misses = {...await _store.readMisses()};
    final next = VisitReminderRules.afterDidntGo(
      misses[cafeId]?.misses ?? 0,
      at,
    );
    misses[cafeId] = (
      misses: next.misses,
      pausedUntil: next.pausedUntil ?? misses[cafeId]?.pausedUntil,
    );
    await _store.writeMisses(misses);
    if (next.pausedUntil != null) {
      logAppEvent(
        NotificationEvents.postVisitPaused,
        properties: {
          'cafe_id': cafeId,
          'days': VisitReminderRules.missPause.inDays,
        },
      );
    }
  }

  /// "I went" ends a run of misses.
  Future<void> _went(String cafeId) async {
    final misses = {...await _store.readMisses()};
    final entry = misses[cafeId];
    if (entry == null || entry.misses == 0) return;
    misses[cafeId] = (misses: 0, pausedUntil: entry.pausedUntil);
    await _store.writeMisses(misses);
  }

  Future<List<PendingVisitReminder>> _sweep() async {
    final pending = await _store.readPending();
    final last = await _store.readLastDeliveredDay();
    final swept = VisitReminderRules.sweep(pending, _now(), last);
    if (swept.upcoming.length != pending.length) {
      await _store.writePending(swept.upcoming);
    }
    final delivered = swept.lastDelivered;
    if (delivered != null && delivered != last) {
      await _store.writeLastDeliveredDay(delivered);
    }
    return swept.upcoming;
  }

  void _onTap(NotificationTap tap) {
    final cafeId = tap.payload;
    if (cafeId == null || cafeId.isEmpty) return;
    if (tap.actionId == VisitReminderActions.didntGo) {
      // Android routes this button to the background isolate; iOS may
      // bring it here.
      unawaited(_didntGo(cafeId, _now()));
      return;
    }
    // The body and "I went" do the same thing.
    logAppEvent(
      NotificationEvents.postVisitOpened,
      properties: {
        'cafe_id': cafeId,
        'action': tap.actionId == VisitReminderActions.went ? 'went' : 'body',
      },
    );
    unawaited(_went(cafeId));
    openRequests.value = VisitReminderOpen(cafeId: cafeId);
  }

  /// Marking a cafe Been (or rating it, which marks it Been) before its
  /// reminder fires makes the reminder pointless.
  Future<void> _onStatuses(CafeStatusState state) async {
    final pending = await _store.readPending();
    final done = [
      for (final p in pending)
        if (state.statusFor(p.cafeId) == CafeStatus.been) p,
    ];
    if (done.isEmpty) return;
    for (final p in done) {
      await _notifier.cancel(p.id);
      logAppEvent(
        NotificationEvents.postVisitCancelled,
        properties: {'cafe_id': p.cafeId, 'reason': 'marked_been'},
      );
    }
    await _store.writePending([
      for (final p in pending)
        if (!done.contains(p)) p,
    ]);
  }

  /// Where the OS permission stands. A muted "Visits and ratings" channel
  /// counts as blocked: nothing would arrive, and only the phone's settings
  /// can change it.
  Future<NotificationPermission> permission() async {
    final appEnabled = await _notifier.areEnabled();
    final muted = appEnabled && await _notifier.channelMuted();
    final asks = await _store.readSystemAsks();
    if (appEnabled && !asks.everGranted) await _store.markEverGranted();
    return VisitReminderRules.permissionFrom(
      enabled: appEnabled && !muted,
      isIOS: _isIOS,
      systemAsks: asks.asks,
      everGranted: asks.everGranted || appEnabled,
      lastAskInstant: asks.lastAskInstant,
    );
  }

  /// Notifications are on for Nook but its reminders channel is muted.
  Future<bool> channelMuted() async =>
      await _notifier.areEnabled() && await _notifier.channelMuted();

  Future<bool> remindersEnabled() => _store.readEnabled();

  /// A Directions tap on [cafeId], before Maps opens. Works out the real
  /// send time (90 min after the tap, or after opening for a cafe that is
  /// closed now but opens before then; 09:00-21:00; one a day; paused
  /// cafes skipped) and whether to ask. Nothing to send means no ask.
  ///
  /// [operatingHours] is the cafe's `operating_hours` JSON.
  Future<DirectionsDecision> onDirectionsTap({
    required String cafeId,
    required String cafeName,
    required CafeStatus status,
    Map<String, dynamic>? operatingHours,
  }) async {
    final at = _now();
    void reminderSkipped(ReminderSkipReason reason) => logAppEvent(
      NotificationEvents.postVisitSkipped,
      properties: {'cafe_id': cafeId, 'reason': reason.wire},
    );
    void askSkipped(String reason) => logAppEvent(
      NotificationEvents.prePromptSkipped,
      properties: {'cafe_id': cafeId, 'reason': reason},
    );

    try {
      await _drainQueue();
      await _store.writeTrip(null);
      if (!await _store.readEnabled()) {
        reminderSkipped(ReminderSkipReason.disabled);
        askSkipped(PrePromptSkipReason.disabled.wire);
        return DirectionsDecision.none;
      }
      if (status == CafeStatus.been) {
        reminderSkipped(ReminderSkipReason.alreadyBeen);
        askSkipped(ReminderSkipReason.alreadyBeen.wire);
        return DirectionsDecision.none;
      }
      final open = CafeOpenAtTap.fromHours(operatingHours, at);
      final plan = VisitReminderRules.plan(
        cafeId: cafeId,
        now: at,
        pending: await _sweep(),
        open: open,
        lastDeliveredDay: await _store.readLastDeliveredDay(),
        pausedUntil: (await _store.readMisses())[cafeId]?.pausedUntil,
        delayOverride: _delayOverride,
      );
      final fireAt = plan.fireAt;
      if (fireAt == null) {
        reminderSkipped(plan.skipReason!);
        askSkipped(plan.skipReason!.wire);
        return DirectionsDecision.none;
      }

      final trip = VisitTrip(
        cafeId: cafeId,
        cafeName: cafeName,
        tappedAt: at,
        fireAt: fireAt,
        cafeOpen: open.wire,
      );
      final permission = await this.permission();
      final block = VisitReminderRules.prePromptBlock(
        now: at,
        shownAt: await _store.readPrePromptsShown(),
        permission: permission,
        remindersEnabled: true,
        holdout: await holdoutArm() == HoldoutArm.holdout,
      );
      if (block == PrePromptSkipReason.granted) {
        askSkipped(block!.wire);
        await _store.writeTrip(trip);
        return DirectionsDecision._(trip: trip);
      }
      if (block != null) {
        askSkipped(block.wire);
        reminderSkipped(ReminderSkipReason.noPermission);
        return DirectionsDecision.none;
      }
      await _store.writeTrip(trip);
      return DirectionsDecision._(trip: trip, ask: true);
    } catch (e) {
      debugPrint('[VisitReminders] directions decision failed: $e');
      return DirectionsDecision.none;
    }
  }

  /// Schedules the trip [onDirectionsTap] kept, if there is one.
  Future<void> confirmTrip() async {
    final trip = await _store.readTrip();
    if (trip == null) return;
    await _store.writeTrip(null);
    await _schedule(trip);
  }

  /// The person chose "Just directions", or Maps did not open.
  Future<void> dropTrip() => _store.writeTrip(null);

  /// A trip kept across the app being killed mid-ask: scheduled if the
  /// permission came through and its time is still ahead.
  Future<void> _resumeTrip() async {
    try {
      final trip = await _store.readTrip();
      if (trip == null) return;
      await _store.writeTrip(null);
      if (!trip.fireAt.isAfter(_now())) return;
      if (await permission() != NotificationPermission.granted) return;
      final pending = await _store.readPending();
      if (pending.any((p) => p.cafeId == trip.cafeId)) return;
      await _schedule(trip);
    } catch (e) {
      debugPrint('[VisitReminders] trip resume failed: $e');
    }
  }

  Future<void> _schedule(VisitTrip trip) async {
    try {
      final pending = await _sweep();
      // Re-plan for the replace list (another cafe the same day, this cafe
      // again); the time was promised at the tap and stays.
      final replace = [
        for (final p in pending)
          if (p.cafeId == trip.cafeId ||
              VisitReminderRules.sameDay(p.fireAt, trip.fireAt))
            p,
      ];
      if (!trip.fireAt.isAfter(_now())) {
        logAppEvent(
          NotificationEvents.postVisitSkipped,
          properties: {
            'cafe_id': trip.cafeId,
            'reason': ReminderSkipReason.outsideWindow.wire,
          },
        );
        return;
      }
      for (final old in replace) {
        await _notifier.cancel(old.id);
      }
      final reminder = PendingVisitReminder(
        id: visitReminderIdFor(trip.cafeId),
        cafeId: trip.cafeId,
        cafeName: trip.cafeName,
        fireAt: trip.fireAt,
      );
      await _notifier.schedule(
        id: reminder.id,
        at: trip.fireAt,
        title: titleFor(trip.cafeName),
        body: body,
        payload: trip.cafeId,
      );
      await _store.writePending([
        for (final p in pending)
          if (!replace.contains(p)) p,
        reminder,
      ]);
      final straight = trip.tappedAt.add(
        _delayOverride ?? VisitReminderRules.delay,
      );
      logAppEvent(
        NotificationEvents.postVisitScheduled,
        properties: {
          'cafe_id': trip.cafeId,
          'delay_min': trip.fireAt.difference(trip.tappedAt).inMinutes,
          'deferred': trip.fireAt != straight,
          'replaced': replace.where((p) => p.cafeId != trip.cafeId).length,
          'cafe_open': trip.cafeOpen,
          'promised_at': trip.fireAt.toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[VisitReminders] schedule failed: $e');
    }
  }

  Future<int> recordPrePromptShown() async {
    await _store.addPrePromptShown(_now());
    return (await _store.readPrePromptsShown()).length;
  }

  /// Shows the system dialog. When granted after the Directions ask, the
  /// trip it was about is scheduled at the time the ask promised.
  Future<bool> requestPermission({required String trigger}) async {
    final watch = Stopwatch()..start();
    final granted = await _notifier.requestPermission();
    // Under ~0.4 s, no dialog was on screen: the OS answered by itself.
    final instant = watch.elapsedMilliseconds < 400;
    await _store.recordSystemAsk(granted: granted, instant: instant);
    logAppEvent(
      NotificationEvents.permissionResult,
      properties: {
        'trigger': trigger,
        'granted': granted,
        'prompted': !instant,
      },
    );
    if (trigger == NotificationPromptTrigger.directions) {
      if (granted) {
        await confirmTrip();
      } else {
        await dropTrip();
      }
    }
    return granted;
  }

  /// The phone's settings: the reminders channel's own page when it is the
  /// channel that is muted.
  Future<void> openSystemSettings() async =>
      _notifier.openSettings(channel: await channelMuted());

  /// The Settings switch. Off cancels whatever is pending.
  Future<void> setEnabled(bool value) async {
    await _store.writeEnabled(value);
    if (value) return;
    final pending = await _store.readPending();
    for (final p in pending) {
      await _notifier.cancel(p.id);
      logAppEvent(
        NotificationEvents.postVisitCancelled,
        properties: {'cafe_id': p.cafeId, 'reason': 'turned_off'},
      );
    }
    await _store.writePending(const []);
  }
}
