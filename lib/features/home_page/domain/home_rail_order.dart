import 'package:nook/core/preferences/onboarding_purpose_store.dart';

/// Home's shelves, in their default order.
enum HomeRail {
  nearby,
  featured,
  specialty,
  localBeans,
  newest,
  laptopFriendly,
  trending,
  topRated,
}

/// The shelves that answer a purpose, best first. The first one that has
/// cafes leads Home. "Just exploring" keeps the default order.
List<HomeRail> purposeRails(OnboardingPurpose? purpose) => switch (purpose) {
  OnboardingPurpose.work => const [HomeRail.laptopFriendly],
  OnboardingPurpose.date => const [HomeRail.trending, HomeRail.featured],
  OnboardingPurpose.specialty => const [
    HomeRail.specialty,
    HomeRail.localBeans,
  ],
  OnboardingPurpose.exploring || null => const [],
};

/// Home's shelf order for [purpose]: the default, with the first shelf
/// in [available] that answers the purpose moved to the top.
List<HomeRail> orderHomeRails(
  OnboardingPurpose? purpose, {
  required Set<HomeRail> available,
}) {
  final order = [...HomeRail.values];
  for (final rail in purposeRails(purpose)) {
    if (available.contains(rail)) {
      order
        ..remove(rail)
        ..insert(0, rail);
      break;
    }
  }
  return order;
}
