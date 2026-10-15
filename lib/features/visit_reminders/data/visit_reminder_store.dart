import 'dart:convert';

import 'package:nook/features/visit_reminders/domain/visit_reminder_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What Nook remembers on this phone about visit reminders: the ones the OS
/// is holding, the day one last went out, the Settings switch, how often the
/// in-app ask was shown, and what the system dialog said.
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
