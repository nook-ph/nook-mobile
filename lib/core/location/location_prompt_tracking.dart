import 'package:geolocator/geolocator.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/preferences/session_prompts.dart';

/// Where a location prompt was shown, for `location_prompt_shown` and
/// `location_permission_result`.
abstract final class LocationPromptSurface {
  /// The Map tab's first-visit prompt.
  static const map = 'map';

  /// The Map tab's recenter ("my location") button.
  static const mapFab = 'map_fab';

  /// Home's location pre-prompt.
  static const home = 'home';

  /// The saver survey's "Too far from me" follow-up.
  static const saverSurvey = 'saver_survey';
}

/// The `result` value for a permission answer: `granted` (always),
/// `while_in_use`, `denied`, `denied_forever`, or `unavailable` (the platform
/// could not tell).
String locationPermissionResult(LocationPermission permission) =>
    switch (permission) {
      LocationPermission.always => 'granted',
      LocationPermission.whileInUse => 'while_in_use',
      LocationPermission.denied => 'denied',
      LocationPermission.deniedForever => 'denied_forever',
      LocationPermission.unableToDetermine => 'unavailable',
    };

/// One location prompt from start to answer, logged at most once each way.
///
/// A flow can show more than one thing (Nook's own sheet, then the system
/// prompt); it is still one prompt in the funnel, so [shown] only logs the
/// first time and [result] only the first answer.
///
/// ```dart
/// final prompt = LocationPromptTracker(LocationPromptSurface.home);
/// prompt.shown();                       // before Nook's sheet or the system
/// final answer = await prompt.request(); // asks the system, logs the answer
/// ```
class LocationPromptTracker {
  LocationPromptTracker(
    this.surface, {
    Future<LocationPermission> Function()? requestPermission,
  }) : _requestPermission = requestPermission ?? Geolocator.requestPermission;

  final String surface;
  final Future<LocationPermission> Function() _requestPermission;

  bool _shown = false;
  bool _answered = false;

  bool get wasShown => _shown;
  bool get answered => _answered;

  /// Logs `location_prompt_shown` the first time.
  void shown() {
    if (_shown) return;
    _shown = true;
    SessionPrompts.noteShown();
    logAppEvent(LocationPromptEvents.shown, properties: {'surface': surface});
  }

  /// Logs `location_permission_result` with [result] the first time. A result
  /// without a prior [shown] logs the shown event first, so the funnel's two
  /// steps always pair up.
  void result(String result, {bool systemPrompt = true}) {
    if (_answered) return;
    shown();
    _answered = true;
    logAppEvent(
      LocationPromptEvents.result,
      properties: {
        'surface': surface,
        'result': result,
        'system_prompt': systemPrompt,
      },
    );
  }

  /// Logs [result] for a permission answer.
  void resultFor(LocationPermission permission) =>
      result(locationPermissionResult(permission));

  /// Asks the system for permission and logs the prompt and its answer. A
  /// platform error logs `unavailable` and rethrows.
  Future<LocationPermission> request() async {
    shown();
    try {
      final answer = await _requestPermission();
      resultFor(answer);
      return answer;
    } catch (_) {
      result('unavailable');
      rethrow;
    }
  }
}
