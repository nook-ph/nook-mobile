import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/home_widget/presentation/widget_links.dart';

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

  test('one tap arriving twice opens once; a later tap opens again', () {
    var now = DateTime.utc(2026, 10, 16, 2);
    WidgetLinks.clock = () => now;
    final uri = Uri.parse('nook://cafe/a?via=widget');
    WidgetLinks.acceptFromPlatform(uri);
    expect(WidgetLinks.take(), isNotNull);
    WidgetLinks.accept(uri);
    expect(WidgetLinks.pending.value, isNull);
    now = now.add(const Duration(seconds: 10));
    WidgetLinks.acceptFromPlatform(uri);
    expect(WidgetLinks.take()?.cafeId, 'a');
    WidgetLinks.acceptFromPlatform(null);
    expect(WidgetLinks.pending.value, isNull);
  });
}
