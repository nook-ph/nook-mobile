import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/preferences/home_location_prompt_store.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('OnboardingPurposeStore', () {
    test('nothing saved reads as null', () async {
      expect(await OnboardingPurposeStore().read(), isNull);
    });

    test('keeps the picked purpose', () async {
      await OnboardingPurposeStore().save(OnboardingPurpose.specialty);
      expect(
        await OnboardingPurposeStore().read(),
        OnboardingPurpose.specialty,
      );
    });

    test('an unknown stored value reads as null', () async {
      SharedPreferences.setMockInitialValues({'onboardingPurpose': 'brunch'});
      expect(await OnboardingPurposeStore().read(), isNull);
    });
  });

  group('HomeLocationPromptStore', () {
    test('counts one Home visit per launch (instance)', () async {
      final launch1 = HomeLocationPromptStore();
      expect(await launch1.recordHomeVisit(), 1);
      expect(await launch1.recordHomeVisit(), 1);

      final launch2 = HomeLocationPromptStore();
      expect(await launch2.recordHomeVisit(), 2);
    });

    test('remembers a cafe view and a dismissal', () async {
      final store = HomeLocationPromptStore();
      expect(await store.hasViewedCafe(), isFalse);
      expect(await store.isDismissed(), isFalse);
      await store.markCafeViewed();
      await store.markDismissed();
      expect(await HomeLocationPromptStore().hasViewedCafe(), isTrue);
      expect(await HomeLocationPromptStore().isDismissed(), isTrue);
    });
  });
}
