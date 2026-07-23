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
