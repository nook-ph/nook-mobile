import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home_widget/domain/widget_promo_rules.dart';

void main() {
  final now = DateTime.utc(2026, 10, 16, 4);

  WidgetPromoReason? decide({
    WidgetPromoHistory history = const WidgetPromoHistory(),
    int wantToTry = 3,
    bool? notificationsOff = false,
    bool canPin = true,
    int? installed = 0,
    DateTime? at,
  }) => WidgetPromoRules.decide(
    history: history,
    wantToTryCount: wantToTry,
    notificationsOff: notificationsOff,
    canPin: canPin,
    installedCount: installed,
    now: at ?? now,
  );

  test('three Want to try shows the saves card; two does not', () {
    expect(decide(), WidgetPromoReason.saves);
    expect(decide(wantToTry: 2), isNull);
    expect(decide(wantToTry: 0, notificationsOff: true), isNull);
  });

  test('notifications off: offered with one save, once', () {
    expect(
      decide(wantToTry: 1, notificationsOff: true),
      WidgetPromoReason.noNotifications,
    );
    final after = WidgetPromoRules.afterShown(
      const WidgetPromoHistory(),
      WidgetPromoReason.noNotifications,
      now,
    );
    final later = now.add(const Duration(days: 20));
    expect(
      decide(history: after, wantToTry: 1, notificationsOff: true, at: later),
      isNull,
    );
    // The saves card can still be the second show.
    expect(
      decide(history: after, wantToTry: 3, notificationsOff: true, at: later),
      WidgetPromoReason.saves,
    );
  });

  test('at most twice, 14+ days apart', () {
    final once = WidgetPromoRules.afterShown(
      const WidgetPromoHistory(),
      WidgetPromoReason.saves,
      now,
    );
    expect(
      decide(history: once, at: now.add(const Duration(days: 13))),
      isNull,
    );
    final fourteen = now.add(const Duration(days: 14));
    expect(decide(history: once, at: fourteen), WidgetPromoReason.saves);
    final twice = WidgetPromoRules.afterShown(
      once,
      WidgetPromoReason.saves,
      fourteen,
    );
    expect(twice.shownCount, 2);
    expect(
      decide(history: twice, at: fourteen.add(const Duration(days: 60))),
      isNull,
    );
  });

  test('never after Add widget, with a widget placed, or without pinning', () {
    expect(decide(history: const WidgetPromoHistory(added: true)), isNull);
    expect(decide(installed: 1), isNull);
    expect(decide(canPin: false), isNull);
    // An unknown widget count does not block.
    expect(decide(installed: null), WidgetPromoReason.saves);
  });
}
