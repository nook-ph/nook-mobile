import 'package:shared_preferences/shared_preferences.dart';

/// What a new user said they are looking for on the last onboarding step.
/// [key] is what is stored and what analytics reports.
enum OnboardingPurpose {
  work('work'),
  date('date'),
  specialty('specialty'),
  exploring('exploring');

  const OnboardingPurpose(this.key);

  final String key;

  static OnboardingPurpose? fromKey(String? key) {
    for (final purpose in values) {
      if (purpose.key == key) return purpose;
    }
    return null;
  }
}

/// Keeps the onboarding purpose on the device. Not tied to an account: it is
/// picked before sign-in, and only decides which Home shelf leads.
class OnboardingPurposeStore {
  static const _key = 'onboardingPurpose';

  Future<OnboardingPurpose?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return OnboardingPurpose.fromKey(prefs.getString(_key));
  }

  Future<void> save(OnboardingPurpose purpose) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, purpose.key);
  }
}
