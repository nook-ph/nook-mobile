import 'dart:convert';
import 'dart:math';

import 'package:nook/features/visit_reminders/domain/visit_reminder_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What Nook remembers on this phone about visit reminders: the ones the OS
/// is holding, the day one last went out, the Settings switch, how often the
/// in-app ask was shown, what the system dialog said, the Directions trip
/// waiting on the ask, "Didn't go" per cafe, and the install's holdout id.
///
/// Phone-only, like the guest saves: no server, nothing per account.
class VisitReminderStore {
  static const _pendingKey = 'visitReminders.pending';
  static const _lastDeliveredKey = 'visitReminders.lastDeliveredDay';
  static const _enabledKey = 'visitReminders.enabled';
  static const _prePromptsKey = 'visitReminders.prePromptsShownAt';
  static const _systemAsksKey = 'visitReminders.systemAsks';
  static const _everGrantedKey = 'visitReminders.everGranted';
  static const _lastAskInstantKey = 'visitReminders.lastAskInstant';
  static const _tripKey = 'visitReminders.trip';
  static const _missesKey = 'visitReminders.misses';
  static const _installIdKey = 'visitReminders.installId';
  static const _handledLaunchKey = 'visitReminders.handledLaunch';

  /// Events from a notification button tapped while Nook was not running
  /// ("Didn't go"): written by the background isolate, sent by the app the
  /// next time it is open.
  static const queuedEventsKey = 'visitReminders.queuedEvents';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<List<PendingVisitReminder>> readPending() async {
    final raw = (await _prefs).getString(_pendingKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [for (final item in list) ?PendingVisitReminder.fromJson(item)];
    } catch (_) {
      return const [];
    }
  }

  Future<void> writePending(List<PendingVisitReminder> pending) async {
    await (await _prefs).setString(
      _pendingKey,
      jsonEncode([for (final p in pending) p.toJson()]),
    );
  }

  Future<DateTime?> readLastDeliveredDay() async {
    final ms = (await _prefs).getInt(_lastDeliveredKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> writeLastDeliveredDay(DateTime day) async {
    await (await _prefs).setInt(_lastDeliveredKey, day.millisecondsSinceEpoch);
  }

  /// The Settings switch. On unless the person turned it off.
  Future<bool> readEnabled() async =>
      (await _prefs).getBool(_enabledKey) ?? true;

  Future<void> writeEnabled(bool value) async {
    await (await _prefs).setBool(_enabledKey, value);
  }

  Future<List<DateTime>> readPrePromptsShown() async {
    final list = (await _prefs).getStringList(_prePromptsKey) ?? const [];
    return [
      for (final s in list)
        if (int.tryParse(s) case final ms?)
          DateTime.fromMillisecondsSinceEpoch(ms),
    ];
  }

  Future<void> addPrePromptShown(DateTime at) async {
    final prefs = await _prefs;
    final list = prefs.getStringList(_prePromptsKey) ?? const [];
    await prefs.setStringList(_prePromptsKey, [
      ...list,
      '${at.millisecondsSinceEpoch}',
    ]);
  }

  Future<({int asks, bool everGranted, bool lastAskInstant})>
  readSystemAsks() async {
    final prefs = await _prefs;
    return (
      asks: prefs.getInt(_systemAsksKey) ?? 0,
      everGranted: prefs.getBool(_everGrantedKey) ?? false,
      lastAskInstant: prefs.getBool(_lastAskInstantKey) ?? false,
    );
  }

  Future<void> recordSystemAsk({
    required bool granted,
    required bool instant,
  }) async {
    final prefs = await _prefs;
    await prefs.setInt(_systemAsksKey, (prefs.getInt(_systemAsksKey) ?? 0) + 1);
    await prefs.setBool(_lastAskInstantKey, !granted && instant);
    if (granted) await prefs.setBool(_everGrantedKey, true);
  }

  Future<void> markEverGranted() async {
    await (await _prefs).setBool(_everGrantedKey, true);
  }

  /// The Directions trip the ask is about, kept until it is scheduled or
  /// dropped, so a reminder the person asked for survives the app being
  /// killed between the tap and the system dialog's answer.
  Future<VisitTrip?> readTrip() async {
    final raw = (await _prefs).getString(_tripKey);
    if (raw == null) return null;
    try {
      return VisitTrip.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> writeTrip(VisitTrip? trip) async {
    final prefs = await _prefs;
    if (trip == null) {
      await prefs.remove(_tripKey);
    } else {
      await prefs.setString(_tripKey, jsonEncode(trip.toJson()));
    }
  }

  /// "Didn't go" in a row, and any pause, per cafe id.
  Future<Map<String, ({int misses, DateTime? pausedUntil})>>
  readMisses() async {
    final raw = (await _prefs).getString(_missesKey);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return const {};
      return {
        for (final e in map.entries)
          if (e.value case {'misses': final int misses})
            '${e.key}': (
              misses: misses,
              pausedUntil: switch (e.value['paused_until']) {
                final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
                _ => null,
              },
            ),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> writeMisses(
    Map<String, ({int misses, DateTime? pausedUntil})> misses,
  ) async {
    await (await _prefs).setString(
      _missesKey,
      jsonEncode({
        for (final e in misses.entries)
          e.key: {
            'misses': e.value.misses,
            'paused_until': ?e.value.pausedUntil?.millisecondsSinceEpoch,
          },
      }),
    );
  }

  /// The notification that last launched the app, once handled. Android
  /// reports the same launch again when the app is reopened from Recents
  /// after the process died; this tells a repeat from a new tap.
  Future<String?> readHandledLaunch() async =>
      (await _prefs).getString(_handledLaunchKey);

  Future<void> writeHandledLaunch(String? key) async {
    final prefs = await _prefs;
    if (key == null) {
      await prefs.remove(_handledLaunchKey);
    } else {
      await prefs.setString(_handledLaunchKey, key);
    }
  }

  /// A random id for this install, made on first read; only for the
  /// holdout bucket, never sent. [created] is true the first time.
  /// One read (and, on a fresh install, one id) however many callers ask
  /// at once: the app-open state log and a Directions tap can overlap.
  Future<({String id, bool created})> installId() {
    final known = _installId;
    if (known != null) {
      return known.then((r) => (id: r.id, created: false));
    }
    final first = _readOrCreateInstallId();
    _installId = first;
    first.catchError((Object _) {
      _installId = null;
      return (id: '', created: false);
    });
    return first;
  }

  Future<({String id, bool created})>? _installId;

  Future<({String id, bool created})> _readOrCreateInstallId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_installIdKey);
    if (existing != null && existing.isNotEmpty) {
      return (id: existing, created: false);
    }
    final random = Random.secure();
    final id = [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    await prefs.setString(_installIdKey, id);
    return (id: id, created: true);
  }

  /// Reads and clears the events the background isolate queued. Reloads
  /// first: that isolate wrote to the platform store behind this one's
  /// cache.
  Future<List<Map<String, Object>>> takeQueuedEvents() async {
    final prefs = await _prefs;
    await prefs.reload();
    final list = prefs.getStringList(queuedEventsKey) ?? const [];
    if (list.isEmpty) return const [];
    await prefs.remove(queuedEventsKey);
    final events = <Map<String, Object>>[];
    for (final raw in list) {
      try {
        final map = jsonDecode(raw);
        if (map is Map) {
          events.add({
            for (final e in map.entries)
              if (e.value != null) '${e.key}': e.value as Object,
          });
        }
      } catch (_) {}
    }
    return events;
  }

  /// Called from the background isolate.
  static Future<void> queueEvent(Map<String, Object> event) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final list = prefs.getStringList(queuedEventsKey) ?? const [];
    await prefs.setStringList(queuedEventsKey, [...list, jsonEncode(event)]);
  }
}

/// A Directions tap Nook may remind about: the cafe, the tap, when the
/// reminder would go out, and whether the cafe was open.
class VisitTrip {
  const VisitTrip({
    required this.cafeId,
    required this.cafeName,
    required this.tappedAt,
    required this.fireAt,
    required this.cafeOpen,
  });

  final String cafeId;
  final String cafeName;
  final DateTime tappedAt;
  final DateTime fireAt;

  /// [CafeOpenAtTap.wire].
  final String cafeOpen;

  Map<String, Object> toJson() => {
    'cafe_id': cafeId,
    'cafe_name': cafeName,
    'tapped_at': tappedAt.millisecondsSinceEpoch,
    'fire_at': fireAt.millisecondsSinceEpoch,
    'cafe_open': cafeOpen,
  };

  static VisitTrip? fromJson(Object? json) {
    if (json case {
      'cafe_id': final String cafeId,
      'cafe_name': final String cafeName,
      'tapped_at': final int tappedAt,
      'fire_at': final int fireAt,
      'cafe_open': final String cafeOpen,
    }) {
      return VisitTrip(
        cafeId: cafeId,
        cafeName: cafeName,
        tappedAt: DateTime.fromMillisecondsSinceEpoch(tappedAt),
        fireAt: DateTime.fromMillisecondsSinceEpoch(fireAt),
        cafeOpen: cafeOpen,
      );
    }
    return null;
  }
}
