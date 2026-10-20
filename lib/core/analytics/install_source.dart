import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sets the `install_source` person property, once per install.
///
/// On the first open it reads the link that launched the app: its `src`
/// query parameter (`https://www.nookph.app/c/abc?src=ig_bio` →
/// `ig_bio`) becomes the source, else `organic`. PostHog `$set_once` keeps
/// the first value a person ever got, so a later identify (sign-in merges the
/// anonymous person) does not overwrite it.
///
/// An install that already ran an older build (onboarding seen before this
/// shipped) gets `existing` rather than a misleading `organic`.
///
/// Limits: a store install does not carry the link that led to the store
/// (no deferred deep linking or Play install referrer here), so `src` is only
/// seen when the very first open comes from a tagged link.
class InstallSourceRecorder {
  InstallSourceRecorder({
    Future<Uri?> Function()? initialLink,
    Future<void> Function(Map<String, Object> properties)? setOnce,
    Future<SharedPreferences> Function()? prefs,
  }) : _initialLink = initialLink ?? AppLinks().getInitialLink,
       _setOnce = setOnce ?? _posthogSetOnce,
       _prefs = prefs ?? SharedPreferences.getInstance;

  final Future<Uri?> Function() _initialLink;
  final Future<void> Function(Map<String, Object>) _setOnce;
  final Future<SharedPreferences> Function() _prefs;

  @visibleForTesting
  static const recordedKey = 'installSourceRecorded';

  /// Set by onboarding; present before this shipped means an older install.
  static const _onboardingKey = 'hasSeenOnboarding';

  static const organic = 'organic';
  static const existing = 'existing';

  static Future<void> _posthogSetOnce(Map<String, Object> properties) =>
      Posthog().setPersonProperties(userPropertiesToSetOnce: properties);

  /// The `src` parameter of [link], lower-cased and limited to letters,
  /// digits, `_`, `-` and `.` (at most 64), else [organic].
  static String sourceFrom(Uri? link) {
    final raw = link?.queryParameters['src']?.trim().toLowerCase() ?? '';
    if (raw.isEmpty || raw.length > 64) return organic;
    return RegExp(r'^[a-z0-9_.\-]+$').hasMatch(raw) ? raw : organic;
  }

  /// Records the source the first time it runs on this install; later calls
  /// do nothing. Never throws.
  Future<void> recordOnFirstOpen() async {
    try {
      final prefs = await _prefs();
      if (prefs.getBool(recordedKey) ?? false) return;

      final String source;
      if (prefs.getBool(_onboardingKey) ?? false) {
        source = existing;
      } else {
        Uri? link;
        try {
          link = await _initialLink().timeout(const Duration(seconds: 2));
        } catch (_) {
          // No link, or the platform did not answer: organic.
        }
        source = sourceFrom(link);
      }

      await _setOnce({RetentionPersonProperties.installSource: source});
      await prefs.setBool(recordedKey, true);
    } catch (e) {
      debugPrint('install_source not recorded: $e');
    }
  }
}
