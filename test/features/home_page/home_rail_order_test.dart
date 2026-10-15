import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/preferences/onboarding_purpose_store.dart';
import 'package:nook/features/home_page/domain/home_rail_order.dart';

void main() {
  final all = HomeRail.values.toSet();

  test('no purpose keeps the default order', () {
    expect(orderHomeRails(null, available: all), HomeRail.values);
  });

  test('"Just exploring" keeps the default order', () {
    expect(
      orderHomeRails(OnboardingPurpose.exploring, available: all),
      HomeRail.values,
    );
  });

  test('work leads with Laptop-friendly', () {
    final order = orderHomeRails(OnboardingPurpose.work, available: all);
    expect(order.first, HomeRail.laptopFriendly);
    expect(order.toSet(), all);
    expect(order.length, HomeRail.values.length);
  });

  test('specialty leads with Specialty coffee', () {
    expect(
      orderHomeRails(OnboardingPurpose.specialty, available: all).first,
      HomeRail.specialty,
    );
  });

  test('falls back to the next matching shelf when the best is empty', () {
    expect(
      orderHomeRails(
        OnboardingPurpose.specialty,
        available: all.difference({HomeRail.specialty}),
      ).first,
      HomeRail.localBeans,
    );
    expect(
      orderHomeRails(
        OnboardingPurpose.date,
        available: all.difference({HomeRail.trending}),
      ).first,
      HomeRail.featured,
    );
  });

  test('no matching shelf with cafes keeps the default order', () {
    expect(
      orderHomeRails(
        OnboardingPurpose.work,
        available: all.difference({HomeRail.laptopFriendly}),
      ),
      HomeRail.values,
    );
  });
}
