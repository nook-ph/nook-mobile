import 'package:flutter/foundation.dart';

/// Escape hatch for verifying instrumentation from a local run:
///
/// ```sh
/// flutter run --dart-define=NOOK_FORCE_ANALYTICS=true
/// ```
const bool _forceAnalytics = bool.fromEnvironment('NOOK_FORCE_ANALYTICS');

/// Whether analytics may leave the device.
///
/// Release only. `flutter run` builds in debug (and `--profile` in profile), so
/// without this gate every tap during local development was captured into the
/// production PostHog project. That is not just noise in the funnel: the same
/// four events back the owner-facing cafe reporting, so development traffic
/// inflated view/direction counts that real cafe owners read as their own.
///
/// TestFlight and store builds are release builds, so they still report.
const bool kAnalyticsEnabled = kReleaseMode || _forceAnalytics;

/// Session replay settings, read from `.env` so a build can turn replay off or
/// sample it locally without a code change.
///
/// - `POSTHOG_SESSION_REPLAY`: `false` turns recording off. Anything else
///   (including unset) leaves it on.
/// - `POSTHOG_REPLAY_SAMPLE_RATE`: a number from 0 to 1. Unset leaves sampling
///   to the project's remote setting (Settings > Session replay > Sampling),
///   which is where volume should normally be tuned. A local value overrides
///   the remote one, so only set it to pin a build's rate.
class ReplaySettings {
  const ReplaySettings({required this.enabled, this.sampleRate});

  final bool enabled;
  final double? sampleRate;

  static ReplaySettings fromEnv(Map<String, String> env) {
    final flag = env['POSTHOG_SESSION_REPLAY']?.trim().toLowerCase();
    final rate = double.tryParse(
      env['POSTHOG_REPLAY_SAMPLE_RATE']?.trim() ?? '',
    );
    return ReplaySettings(
      enabled: flag != 'false' && flag != '0',
      sampleRate: rate == null || rate.isNaN ? null : rate.clamp(0.0, 1.0),
    );
  }
}
