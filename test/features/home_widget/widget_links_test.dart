import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home_widget/presentation/widget_links.dart';

import '../../core/analytics/recording_analytics.dart';

void main() {
  tearDown(WidgetLinks.reset);

  test('a cafe row opens its page over Home', () {
    expect(WidgetLinks.accept(Uri.parse('nook://cafe/abc-1?via=widget')), '/');
    final link = WidgetLinks.take()!;
    expect(link.target, WidgetLinkTarget.cafe);
    expect(link.location, '/cafe/abc-1');
    expect(link.tap, 'cafe');
    expect(WidgetLinks.pending.value, isNull);
  });

  test('header, stale and empty taps', () {
    expect(
      WidgetLink.parse(Uri.parse('nook://saved?via=widget'))!.tap,
      'header',
    );
    expect(
      WidgetLink.parse(Uri.parse('nook://saved?via=widget&tap=stale'))!.tap,
      'stale',
    );
    final empty = WidgetLink.parse(Uri.parse('nook://home?via=widget'))!;
    expect(empty.target, WidgetLinkTarget.home);
    expect(empty.location, isNull);
  });

  test('other links are left to the router', () {
    expect(WidgetLinks.accept(Uri.parse('/cafe/abc')), isNull);
    expect(WidgetLinks.accept(Uri.parse('nook://cafe/abc')), isNull);
    expect(WidgetLinks.accept(Uri.parse('https://www.nookph.app/u/x')), isNull);
    expect(WidgetLinks.pending.value, isNull);
  });

  test('one tap arriving twice is logged once; a later tap opens again', () {
    final analytics = RecordingAnalytics.install(addTearDown);
    var now = DateTime.utc(2026, 10, 16, 2);
    WidgetLinks.clock = () => now;
    final uri = Uri.parse('nook://cafe/a?via=widget');
    // Cold start: the router's initial route, then the plugin's launch link.
    WidgetLinks.accept(uri);
    expect(WidgetLinks.take()?.cafeId, 'a');
    WidgetLinks.acceptFromPlatform(uri);
    expect(WidgetLinks.pending.value, isNull);
    expect(analytics.names, ['widget_tapped']);
    now = now.add(const Duration(seconds: 10));
    WidgetLinks.acceptFromPlatform(uri);
    expect(WidgetLinks.take()?.cafeId, 'a');
    expect(analytics.names, ['widget_tapped', 'widget_tapped']);
    WidgetLinks.acceptFromPlatform(null);
    expect(WidgetLinks.pending.value, isNull);
  });

  test('warm tap: the router\'s copy after the cafe opened opens it again '
      'over the Home its redirect lands on, without a second event', () {
    final analytics = RecordingAnalytics.install(addTearDown);
    WidgetLinks.clock = () => DateTime.utc(2026, 10, 16, 2);
    final uri = Uri.parse('nook://cafe/b?via=widget');
    WidgetLinks.acceptFromPlatform(uri);
    expect(WidgetLinks.take()?.cafeId, 'b'); // pushed
    expect(WidgetLinks.accept(uri), '/'); // replaces the stack
    expect(WidgetLinks.take()?.cafeId, 'b'); // so push it again
    expect(analytics.names, ['widget_tapped']);
  });

  test(
    'warm tap: the router\'s copy before the cafe opened changes nothing',
    () {
      WidgetLinks.clock = () => DateTime.utc(2026, 10, 16, 2);
      final uri = Uri.parse('nook://cafe/b?via=widget');
      WidgetLinks.acceptFromPlatform(uri);
      WidgetLinks.accept(uri);
      expect(WidgetLinks.take()?.cafeId, 'b');
      expect(WidgetLinks.pending.value, isNull);
    },
  );

  test('a link not opened within a minute is dropped', () {
    var now = DateTime.utc(2026, 10, 16, 2);
    WidgetLinks.clock = () => now;
    WidgetLinks.accept(Uri.parse('nook://cafe/c?via=widget'));
    now = now.add(const Duration(minutes: 5)); // onboarding first
    expect(WidgetLinks.take(), isNull);
    expect(WidgetLinks.pending.value, isNull);
  });

  test('a header tap from the plugin and the router is one tap', () {
    WidgetLinks.clock = () => DateTime.utc(2026, 10, 16, 2);
    // The plugin's link, then go_router's normalized one (empty path → /).
    WidgetLinks.acceptFromPlatform(Uri.parse('nook://saved?via=widget'));
    expect(WidgetLinks.take()?.target, WidgetLinkTarget.saved);
    expect(WidgetLinks.accept(Uri.parse('nook://saved/?via=widget')), '/');
    expect(WidgetLinks.pending.value, isNull);
    // A different target right after is a new tap.
    WidgetLinks.accept(Uri.parse('nook://home/?via=widget'));
    expect(WidgetLinks.take()?.target, WidgetLinkTarget.home);
  });

  test('a link needs the shell only once it has shown and is gone', () {
    RecordingAnalytics.install(addTearDown);
    // Cold start: the shell has not shown yet; the app gets there itself.
    WidgetLinks.acceptFromPlatform(Uri.parse('nook://cafe/a?via=widget'));
    expect(WidgetLinks.needsShell, isFalse);

    WidgetLinks.openerAttached();
    expect(WidgetLinks.needsShell, isFalse, reason: 'the shell opens it');

    // Signed out to /login: the shell is gone.
    WidgetLinks.openerDetached();
    expect(WidgetLinks.needsShell, isTrue);

    WidgetLinks.take();
    expect(WidgetLinks.needsShell, isFalse, reason: 'nothing waits');
  });
}
