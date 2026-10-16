import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/home_widget_events.dart';
import 'package:nook/core/presentation/session_ask_budget.dart';
import 'package:nook/features/home_widget/data/home_widget_platform.dart';
import 'package:nook/features/home_widget/data/widget_promo_store.dart';
import 'package:nook/features/home_widget/domain/notification_decline.dart';
import 'package:nook/features/home_widget/domain/saved_cafes_widget_data.dart';
import 'package:nook/features/home_widget/domain/widget_promo_rules.dart';
import 'package:nook/features/home_widget/presentation/widgets/home_widget_promo_card.dart';
import 'package:nook/features/home_widget/presentation/widgets/on_screen_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analytics/recording_analytics.dart';

class _FakePlatform implements HomeWidgetPlatform {
  int? count = 0;
  bool? enabled = false;
  int? sdk = 35;
  int pinRequests = 0;

  /// While set, reading the count waits for it.
  Completer<void>? gate;

  @override
  bool get isSupported => true;
  @override
  Future<bool> canPin() async => true;
  @override
  Future<int?> installedCount() async {
    await gate?.future;
    return count;
  }

  @override
  Future<bool?> notificationsEnabled() async => enabled;
  @override
  Future<int?> sdkInt() async => sdk;
  @override
  Future<void> requestPin() async => pinRequests++;
  @override
  Future<void> write(String key, String json) async {}
  @override
  Future<void> redraw() async {}
  @override
  Future<Uri?> launchLink() async => null;
  @override
  Stream<Uri?> get clicks => const Stream.empty();
}

class _Declined implements NotificationDeclineSource {
  _Declined([this.kind = NotificationDecline.deniedAfterAsk]);

  final NotificationDecline kind;

  @override
  Future<NotificationDecline?> decline() async => kind;
}

final _cafes = ValueNotifier<List<WidgetCafe>?>([
  for (var i = 0; i < 3; i++) WidgetCafe(id: '$i', name: 'Cafe $i'),
]);

void main() {
  late _FakePlatform platform;
  late RecordingAnalytics analytics;
  final store = WidgetPromoStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HomeWidgetPromo.resetSession();
    platform = _FakePlatform();
  });

  Widget promo({
    NotificationDeclineSource? declines,
    SessionAskBudget? budget,
  }) => HomeWidgetPromo(
    platform: platform,
    store: store,
    feed: _cafes,
    declines: declines ?? const UnknownNotificationDecline(),
    budget: budget ?? SessionAskBudget(),
    pinSettle: Duration.zero,
  );

  /// The card under [above] pixels of filler in a scroll view.
  Widget page(Widget card, {double above = 0}) => MaterialApp(
    home: Scaffold(
      body: ListView(
        children: [
          SizedBox(height: above),
          card,
        ],
      ),
    ),
  );

  void scrollTo(WidgetTester tester, double offset) => tester
      .state<ScrollableState>(find.byType(Scrollable))
      .position
      .jumpTo(offset);

  group('a show is counted only when the card is seen', () {
    testWidgets('below the fold: decided, not counted; scrolled in: '
        'counted after a second', (tester) async {
      analytics = RecordingAnalytics.install(addTearDown);
      // Below the 600 px screen, but inside the list's build-ahead area.
      await tester.pumpWidget(page(promo(), above: 700));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(analytics.names, [HomeWidgetEvents.promoShown]);
      expect((await store.read()).shownCount, 0);

      scrollTo(tester, 500);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect((await store.read()).shownCount, 0, reason: 'not a second yet');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect((await store.read()).shownCount, 1);
      expect(analytics.propertiesOf(HomeWidgetEvents.promoViewed), {
        'reason': 'saves',
        'show': 1,
      });
    });

    testWidgets('on screen from the start: counted once', (tester) async {
      analytics = RecordingAnalytics.install(addTearDown);
      await tester.pumpWidget(page(promo()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1, milliseconds: 100));
      await tester.pump(const Duration(seconds: 5));
      expect((await store.read()).shownCount, 1);
      expect(
        analytics.names.where((n) => n == HomeWidgetEvents.promoViewed),
        hasLength(1),
      );
    });

    testWidgets('scrolled away before a second: not counted', (tester) async {
      analytics = RecordingAnalytics.install(addTearDown);
      await tester.pumpWidget(page(promo(), above: 300));
      await tester.pump();
      expect((await store.read()).shownCount, 0, reason: 'fresh store');
      await tester.pump(const Duration(milliseconds: 400));
      scrollTo(tester, 1200);
      await tester.pump();
      expect(find.text(HomeWidgetPromo.savesTitle).hitTestable(), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(analytics.names, isNot(contains(HomeWidgetEvents.promoViewed)));
      expect((await store.read()).shownCount, 0);
    });
  });

  testWidgets('the third save during a decision is looked at again', (
    tester,
  ) async {
    analytics = RecordingAnalytics.install(addTearDown);
    final feed = ValueNotifier<List<WidgetCafe>?>([
      for (var i = 0; i < 2; i++) WidgetCafe(id: '$i', name: 'Cafe $i'),
    ]);
    platform.gate = Completer<void>();
    await tester.pumpWidget(
      page(
        HomeWidgetPromo(
          platform: platform,
          store: store,
          feed: feed,
          pinSettle: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    // The first decision (two saves) is still awaiting the phone.
    feed.value = [
      for (var i = 0; i < 3; i++) WidgetCafe(id: '$i', name: 'Cafe $i'),
    ];
    platform.gate!.complete();
    platform.gate = null;
    await tester.pump();
    await tester.pump();
    expect(find.text(HomeWidgetPromo.savesTitle), findsOneWidget);
  });

  group('notifications-off card', () {
    testWidgets('never asked on Android 13+: the saves card', (tester) async {
      analytics = RecordingAnalytics.install(addTearDown);
      await tester.pumpWidget(page(promo()));
      await tester.pump();
      expect(find.text(HomeWidgetPromo.savesTitle), findsOneWidget);
    });

    testWidgets('after a real decline: the no-notifications card, with its '
        'kind on the view', (tester) async {
      analytics = RecordingAnalytics.install(addTearDown);
      await tester.pumpWidget(page(promo(declines: _Declined())));
      await tester.pump();
      expect(find.text(HomeWidgetPromo.noNotificationsTitle), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(analytics.propertiesOf(HomeWidgetEvents.promoViewed), {
        'reason': 'no_notifications',
        'show': 1,
        'decline_kind': 'system_denied',
      });
    });

    testWidgets('notifications on but the reminders channel muted: the '
        'no-notifications card', (tester) async {
      analytics = RecordingAnalytics.install(addTearDown);
      platform.enabled = true;
      await tester.pumpWidget(
        page(promo(declines: _Declined(NotificationDecline.channelMuted))),
      );
      await tester.pump();
      expect(find.text(HomeWidgetPromo.noNotificationsTitle), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(
        analytics.propertiesOf(HomeWidgetEvents.promoViewed)?['decline_kind'],
        'channel_muted',
      );
    });
  });

  group('Add widget', () {
    Future<void> tapAdd(WidgetTester tester) async {
      await tester.pumpWidget(page(promo()));
      await tester.pump();
      await tester.tap(find.text(HomeWidgetPromo.addLabel));
      await tester.pump();
      await tester.pump();
      expect(platform.pinRequests, 1);
      expect(find.text(HomeWidgetPromo.addLabel), findsNothing);
      expect((await store.read()).added, isFalse, reason: 'not yet known');
    }

    Future<void> resume(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pump();
    }

    testWidgets('count rose on resume: added, confirmed', (tester) async {
      analytics = RecordingAnalytics.install(addTearDown);
      await tapAdd(tester);
      platform.count = 1;
      await resume(tester);
      expect((await store.read()).added, isTrue);
      expect(await store.pendingPin(), isNull);
      expect(analytics.propertiesOf(HomeWidgetEvents.pinResult), {
        'result': 'added',
        'reason': 'saves',
      });
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a rise long after the tap is not credited to the card', (
      tester,
    ) async {
      analytics = RecordingAnalytics.install(addTearDown);
      await store.setPendingPin(
        PendingWidgetPin(
          at: DateTime.now().subtract(const Duration(hours: 2)),
          reason: 'saves',
          countBefore: 0,
        ),
      );
      platform.count = 1;
      await tester.pumpWidget(page(promo()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect((await store.read()).added, isFalse);
      expect(await store.pendingPin(), isNull);
      expect(analytics.propertiesOf(HomeWidgetEvents.pinResult), {
        'result': 'unknown',
        'reason': 'saves',
      });
    });

    testWidgets('cancelled: not retired, the second show stays', (
      tester,
    ) async {
      analytics = RecordingAnalytics.install(addTearDown);
      await tapAdd(tester);
      await resume(tester);
      final history = await store.read();
      expect(history.added, isFalse);
      expect(history.shownCount, 1);
      expect(analytics.propertiesOf(HomeWidgetEvents.pinResult), {
        'result': 'cancelled',
        'reason': 'saves',
      });
      // 14 days on, the card may show again.
      expect(
        WidgetPromoRules.decide(
          history: history,
          wantToTryCount: 3,
          notificationsOff: null,
          canPin: true,
          installedCount: 0,
          now: history.lastShownAt!.add(const Duration(days: 15)),
        ),
        WidgetPromoReason.saves,
      );
    });
  });

  group('buttons', () {
    Widget card(double scale) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(400, 900),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: HomeWidgetPromoCard(
              title: HomeWidgetPromo.savesTitle,
              body: HomeWidgetPromo.savesBody,
              preview: SavedCafesWidgetData.frameAt(
                const [],
                DateTime.utc(2026),
              ),
              names: const {},
              onAdd: () {},
              onDismiss: () {},
            ),
          ),
        ),
      ),
    );

    testWidgets('side by side, same height, at default text', (tester) async {
      await tester.pumpWidget(card(1));
      final add = tester.getRect(find.text(HomeWidgetPromo.addLabel));
      final dismiss = tester.getRect(find.text(HomeWidgetPromo.dismissLabel));
      expect(add.center.dy, closeTo(dismiss.center.dy, 0.5));
      expect(add.left, greaterThan(dismiss.right));
    });

    testWidgets('stacked, Add widget on top, at large text', (tester) async {
      await tester.pumpWidget(card(2));
      final add = tester.getRect(find.text(HomeWidgetPromo.addLabel));
      final dismiss = tester.getRect(find.text(HomeWidgetPromo.dismissLabel));
      expect(add.bottom, lessThan(dismiss.top));
    });
  });

  group('pure parts', () {
    test('pin result from the counts', () {
      expect(WidgetPinResult.of(before: 0, after: 1), WidgetPinResult.added);
      expect(
        WidgetPinResult.of(before: 1, after: 1),
        WidgetPinResult.cancelled,
      );
      expect(
        WidgetPinResult.of(before: 0, after: null),
        WidgetPinResult.unknown,
      );
      expect(WidgetPinResult.of(before: null, after: 1), WidgetPinResult.added);
      expect(
        WidgetPinResult.of(before: null, after: 0),
        WidgetPinResult.unknown,
      );
    });

    test('install source: promo within 10 minutes of the tap', () {
      final tap = DateTime.utc(2026, 10, 16, 5);
      expect(
        WidgetInstallSource.infer(
          lastPinRequest: tap,
          now: tap.add(const Duration(minutes: 3)),
        ),
        'promo',
      );
      expect(
        WidgetInstallSource.infer(
          lastPinRequest: tap,
          now: tap.add(const Duration(minutes: 11)),
        ),
        'launcher',
      );
      expect(
        WidgetInstallSource.infer(lastPinRequest: null, now: tap),
        'launcher',
      );
    });

    test('visible fraction', () {
      const viewport = Rect.fromLTWH(0, 0, 400, 800);
      expect(
        OnScreenDetector.visibleFraction(
          const Rect.fromLTWH(0, 700, 400, 200),
          viewport,
        ),
        0.5,
      );
      expect(
        OnScreenDetector.visibleFraction(
          const Rect.fromLTWH(0, 900, 400, 200),
          viewport,
        ),
        0,
      );
    });
  });

  group('session ask budget', () {
    testWidgets('seen: noted, nothing spent, so the survey does not stack', (
      tester,
    ) async {
      analytics = RecordingAnalytics.install(addTearDown);
      final budget = SessionAskBudget();
      await tester.pumpWidget(page(promo(budget: budget), above: 700));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(budget.anyShown, isFalse, reason: 'decided, not seen yet');

      scrollTo(tester, 500);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();
      expect(budget.anyShown, isTrue);
      expect(budget.canShowSheet, isTrue);
      expect(budget.canShowScoreAsk, isTrue);
      expect(budget.claim(SessionAskKind.saverSurvey), isFalse);
    });

    testWidgets('after a sheet spent the budget it still shows (inline '
        'offers are not held back)', (tester) async {
      analytics = RecordingAnalytics.install(addTearDown);
      final budget = SessionAskBudget()..spend(SessionAskKind.signUpAsk);
      await tester.pumpWidget(page(promo(budget: budget)));
      await tester.pump();
      expect(find.text(HomeWidgetPromo.savesTitle), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(budget.spentBy, SessionAskKind.signUpAsk);
    });
  });
}
