import 'package:shared_preferences/shared_preferences.dart';

/// Dev aid (`AppConstants.fakeStamps`): keeps the stamps made up on this
/// device, per run, so a walkthrough survives leaving the run screen and
/// restarting the app. Nothing here ever reaches the server.
class FakeStampStore {
  static const _keyPrefix = 'fake_stamps_';
  static const _separator = '|';

  /// Stop id → when it was stamped on this device.
  Future<Map<String, DateTime>> read(String runId) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = prefs.getStringList('$_keyPrefix$runId') ?? const [];
    final stamps = <String, DateTime>{};
    for (final entry in entries) {
      final at = entry.lastIndexOf(_separator);
      if (at <= 0) continue;
      final claimedAt = DateTime.tryParse(entry.substring(at + 1));
      if (claimedAt == null) continue;
      stamps[entry.substring(0, at)] = claimedAt;
    }
    return stamps;
  }

  Future<void> add(String runId, String stopId, DateTime claimedAt) async {
    final stamps = await read(runId);
    stamps.putIfAbsent(stopId, () => claimedAt);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_keyPrefix$runId', [
      for (final stamp in stamps.entries)
        '${stamp.key}$_separator${stamp.value.toIso8601String()}',
    ]);
  }

  /// Leaving a run drops its stamps, made-up ones included.
  Future<void> clear(String runId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$runId');
  }
}
