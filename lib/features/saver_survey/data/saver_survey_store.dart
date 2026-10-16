import 'package:shared_preferences/shared_preferences.dart';

/// What the saver survey remembers on this phone: the days the app was
/// opened on, and whether the survey has been shown (it never is again).
class SaverSurveyStore {
  SaverSurveyStore({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const _openDaysKey = 'saver_survey_open_days';
  static const _lastOpenDayKey = 'saver_survey_last_open_day';
  static const _doneKey = 'saver_survey_done';

  final DateTime Function() _now;
  LaunchRecord? _thisLaunch;

  /// Counts this launch, once per instance (the app keeps one for its
  /// lifetime): a new calendar day adds one to the open days. The first
  /// launch ever recorded is the first session.
  Future<LaunchRecord> recordLaunch() async {
    final known = _thisLaunch;
    if (known != null) return known;
    final prefs = await SharedPreferences.getInstance();
    final today = _day(_now());
    final last = prefs.getString(_lastOpenDayKey);
    var days = prefs.getInt(_openDaysKey) ?? 0;
    final first = last == null;
    if (last != today) {
      days += 1;
      await prefs.setInt(_openDaysKey, days);
      await prefs.setString(_lastOpenDayKey, today);
    }
    return _thisLaunch = LaunchRecord(openDays: days, firstSession: first);
  }

  Future<bool> isDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_doneKey) ?? false;
  }

  /// Never shown again: set as the survey opens, so a crash or a swipe away
  /// counts too.
  Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_doneKey, true);
  }

  static String _day(DateTime at) {
    final local = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}

class LaunchRecord {
  const LaunchRecord({required this.openDays, required this.firstSession});

  /// Different days the app was opened on, today included.
  final int openDays;
  final bool firstSession;
}
