import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:nook/core/analytics/analytics_config.dart';
import 'package:nook/core/analytics/screen_tracking.dart';

void main() {
  testWidgets('screen size is added to a copy, so a const properties map '
      'does not make the event throw (and be dropped)', (tester) async {
    const props = {'trigger': 'directions'};
    final event = addScreenSize(
      PostHogEvent(event: 'notification_preprompt_accepted', properties: props),
    );
    expect(event.properties?['trigger'], 'directions');
    expect(event.properties, contains(r'$screen_width'));
    expect(props, hasLength(1));
  });

  String? name(String? routeName, {String root = ScreenNames.home}) =>
      screenNameForRoute(RouteSettings(name: routeName), root: root);

  group('screenNameForRoute', () {
    test('the root route is whatever the shell shows', () {
      expect(name('/', root: ScreenNames.map), ScreenNames.map);
      expect(name('/', root: ScreenNames.onboarding), ScreenNames.onboarding);
    });

    test('GoRoutes map from their path pattern to a human name', () {
      expect(name('/cafe/:id'), ScreenNames.cafeDetails);
      expect(name('/search'), ScreenNames.search);
      expect(name('/login'), ScreenNames.login);
      expect(name('u/:username'), ScreenNames.publicProfile);
      expect(name('c/:code'), ScreenNames.crawlDetail);
    });

    test('pushed pages keep the ScreenNames value they were given', () {
      expect(name(ScreenNames.listDetail), ScreenNames.listDetail);
    });

    test('unnamed routes and unknown paths are not tracked', () {
      expect(name(null), isNull);
      expect(name('  '), isNull);
      expect(name('/not-a-route'), isNull);
    });
  });

  group('ScreenTracker', () {
    setUp(ScreenTracker.instance.resetForTest);

    test('a root screen behind a pushed page is remembered, not reported', () {
      final tracker = ScreenTracker.instance;
      tracker.report(ScreenNames.cafeDetails);
      tracker.showRoot(ScreenNames.map, onTop: false);

      expect(tracker.current, ScreenNames.cafeDetails);
      expect(tracker.rootScreen, ScreenNames.map);
      expect(name('/', root: tracker.rootScreen), ScreenNames.map);
    });

    test('a visible root screen becomes the current screen', () {
      ScreenTracker.instance.showRoot(ScreenNames.profile);
      expect(ScreenTracker.instance.current, ScreenNames.profile);
    });
  });

  group('ReplaySettings.fromEnv', () {
    test('on by default, sampling left to the project setting', () {
      final s = ReplaySettings.fromEnv({});
      expect(s.enabled, isTrue);
      expect(s.sampleRate, isNull);
    });

    test('can be turned off and sampled locally', () {
      final s = ReplaySettings.fromEnv({
        'POSTHOG_SESSION_REPLAY': 'false',
        'POSTHOG_REPLAY_SAMPLE_RATE': '0.25',
      });
      expect(s.enabled, isFalse);
      expect(s.sampleRate, 0.25);
    });

    test('a rate out of range is clamped and junk is ignored', () {
      expect(
        ReplaySettings.fromEnv({'POSTHOG_REPLAY_SAMPLE_RATE': '3'}).sampleRate,
        1.0,
      );
      expect(
        ReplaySettings.fromEnv({
          'POSTHOG_REPLAY_SAMPLE_RATE': 'half',
        }).sampleRate,
        isNull,
      );
    });
  });
}
