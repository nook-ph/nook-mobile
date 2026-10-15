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

/// A reminder asked the app to open a cafe: on its page, and with [rate]
/// straight into marking it Been (which, signed in, leads to rating it).
class VisitReminderOpen {
  const VisitReminderOpen({required this.cafeId, required this.rate});

  final String cafeId;
  final bool rate;
}

/// The one notification Nook sends from the phone: "How was [cafe]?" about
/// 90 minutes after Directions to it. Schedules and cancels it, asks for the
/// permission when the in-app ask is accepted, and turns taps on it into
/// [openRequests] for the router.
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

  static const title = 'How was {cafe}?';
  static const body = 'Tap to rate your visit';

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

  /// The last Directions tap, for the in-app ask on the way back.
  ({String cafeId, String cafeName, DateTime at, bool offered})? _lastTrip;

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

  /// Sends what the background isolate queued and forgets reminders that
  /// have gone out, noting the day for the one-a-day rule.
  Future<void> _catchUp() async {
    try {
      for (final event in await _store.takeQueuedEvents()) {
        if (event['event'] == 'didnt_go') {
          logAppEvent(
            NotificationEvents.postVisitDidntGo,
            properties: {'cafe_id': ?event['cafe_id']},
          );
        }
      }
      await _sweep();
    } catch (e) {
      debugPrint('[VisitReminders] catch-up failed: $e');
    }
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
      // bring it here. Either way: log, nothing else to do.
      logAppEvent(
        NotificationEvents.postVisitDidntGo,
        properties: {'cafe_id': cafeId},
      );
      return;
    }
    final rate = tap.actionId == VisitReminderActions.rate;
    logAppEvent(
      NotificationEvents.postVisitOpened,
      properties: {'cafe_id': cafeId, 'action': rate ? 'rate' : 'open'},
    );
    openRequests.value = VisitReminderOpen(cafeId: cafeId, rate: rate);
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

  Future<NotificationPermission> permission() async {
    final enabled = await _notifier.areEnabled();
    final asks = await _store.readSystemAsks();
    if (enabled && !asks.everGranted) await _store.markEverGranted();
    return VisitReminderRules.permissionFrom(
      enabled: enabled,
      isIOS: _isIOS,
      systemAsks: asks.asks,
      everGranted: asks.everGranted,
      lastAskInstant: asks.lastAskInstant,
    );
  }

  Future<bool> remindersEnabled() => _store.readEnabled();

  /// Directions to [cafeId] just opened a maps app. Schedules the reminder
  /// when it can; otherwise remembers the trip, so the cafe page can offer
  /// the in-app ask when the person comes back.
  Future<void> onDirections({
    required String cafeId,
    required String cafeName,
    required CafeStatus status,
  }) async {
    final at = _now();
    _lastTrip = (cafeId: cafeId, cafeName: cafeName, at: at, offered: false);
    await _scheduleFor(
      cafeId: cafeId,
      cafeName: cafeName,
      tappedAt: at,
      status: status,
    );
  }

  Future<void> _scheduleFor({
    required String cafeId,
    required String cafeName,
    required DateTime tappedAt,
    required CafeStatus status,
  }) async {
    void skipped(ReminderSkipReason reason) => logAppEvent(
      NotificationEvents.postVisitSkipped,
      properties: {'cafe_id': cafeId, 'reason': reason.wire},
    );

    try {
      if (!await _store.readEnabled()) {
        return skipped(ReminderSkipReason.disabled);
      }
      if (await permission() != NotificationPermission.granted) {
        return skipped(ReminderSkipReason.noPermission);
      }
      if (status == CafeStatus.been) {
        return skipped(ReminderSkipReason.alreadyBeen);
      }
      final pending = await _sweep();
      final plan = VisitReminderRules.plan(
        cafeId: cafeId,
        now: tappedAt,
        pending: pending,
        lastDeliveredDay: await _store.readLastDeliveredDay(),
        delayOverride: _delayOverride,
      );
      final fireAt = plan.fireAt;
      if (fireAt == null) return skipped(plan.skipReason!);
      // A late "Turn on" may come after the slot: nothing to send then.
      if (!fireAt.isAfter(_now())) {
        return skipped(ReminderSkipReason.outsideWindow);
      }

      for (final old in plan.replace) {
        await _notifier.cancel(old.id);
      }
      final reminder = PendingVisitReminder(
        id: visitReminderIdFor(cafeId),
        cafeId: cafeId,
        cafeName: cafeName,
        fireAt: fireAt,
      );
      await _notifier.schedule(
        id: reminder.id,
        at: fireAt,
        title: titleFor(cafeName),
        body: body,
        payload: cafeId,
      );
      await _store.writePending([
        for (final p in pending)
          if (!plan.replace.contains(p)) p,
        reminder,
      ]);
      final straight = tappedAt.add(_delayOverride ?? VisitReminderRules.delay);
      logAppEvent(
        NotificationEvents.postVisitScheduled,
        properties: {
          'cafe_id': cafeId,
          'delay_min': fireAt.difference(tappedAt).inMinutes,
          'deferred': fireAt != straight,
          'replaced': plan.replace.where((p) => p.cafeId != cafeId).length,
        },
      );
    } catch (e) {
      debugPrint('[VisitReminders] schedule failed: $e');
    }
  }

  /// Whether the in-app ask may be shown now (see
  /// [VisitReminderRules.canShowPrePrompt]).
  Future<bool> canShowPrePrompt() async {
    try {
      return VisitReminderRules.canShowPrePrompt(
        now: _now(),
        shownAt: await _store.readPrePromptsShown(),
        permission: await permission(),
        remindersEnabled: await _store.readEnabled(),
      );
    } catch (_) {
      return false;
    }
  }

  /// The cafe name for the ask after Directions to [cafeId], if the person
  /// is back soon enough, the ask has not been offered for this trip, and
  /// it may be shown at all. Claims the trip: asked once per tap.
  Future<String?> takeDirectionsPrompt(String cafeId) async {
    final trip = _lastTrip;
    if (trip == null || trip.cafeId != cafeId || trip.offered) return null;
    if (_now().difference(trip.at) >
        VisitReminderRules.directionsPromptFreshness) {
      return null;
    }
    _lastTrip = (
      cafeId: trip.cafeId,
      cafeName: trip.cafeName,
      at: trip.at,
      offered: true,
    );
    if (!await canShowPrePrompt()) return null;
    return trip.cafeName;
  }

  Future<int> recordPrePromptShown() async {
    await _store.addPrePromptShown(_now());
    return (await _store.readPrePromptsShown()).length;
  }

  /// Shows the system dialog. When granted after a Directions ask, the
  /// reminder for that trip is scheduled from the original tap time.
  Future<bool> requestPermission({
    required String trigger,
    CafeStatus Function(String cafeId)? statusOf,
  }) async {
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
    final trip = _lastTrip;
    if (granted &&
        trip != null &&
        trigger == NotificationPromptTrigger.directions) {
      await _scheduleFor(
        cafeId: trip.cafeId,
        cafeName: trip.cafeName,
        tappedAt: trip.at,
        status: statusOf?.call(trip.cafeId) ?? CafeStatus.none,
      );
    }
    return granted;
  }

  Future<void> openSystemSettings() => _notifier.openSettings();

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
