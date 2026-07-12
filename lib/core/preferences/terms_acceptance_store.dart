import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the user has accepted the current Terms of Use (EULA) and
/// Privacy Policy. Acceptance is version-stamped so bumping
/// [AppConstants.termsVersion] forces everyone to re-accept on next launch.
///
/// Used to decide whether the terms agreement is required on the auth entry
/// screen and to record the accepted version + timestamp for audit.
class TermsAcceptanceStore {
  static const _versionKey = 'acceptedTermsVersion';
  static const _acceptedAtKey = 'acceptedTermsAt';

  /// True when the user has already accepted the given [version].
  Future<bool> hasAccepted(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_versionKey) == version;
  }

  /// Records acceptance of [version] with an ISO-8601 UTC timestamp.
  Future<void> markAccepted(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_versionKey, version);
    await prefs.setString(
      _acceptedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }
}
