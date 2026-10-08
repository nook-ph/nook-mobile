import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/router/web_links.dart';

void main() {
  group('WebLinks.username', () {
    test('reads a plain username', () {
      expect(WebLinks.username('charles_jade'), 'charles_jade');
    });

    test('drops a leading @ and surrounding space', () {
      expect(WebLinks.username('%40charles_jade'), 'charles_jade');
      expect(WebLinks.username(' @charles '), 'charles');
    });

    test('rejects empty or junk values', () {
      expect(WebLinks.username(null), isNull);
      expect(WebLinks.username(''), isNull);
      expect(WebLinks.username('@'), isNull);
      expect(WebLinks.username('a/b'), isNull);
      expect(WebLinks.username('<script>'), isNull);
    });
  });

  group('WebLinks.crawl', () {
    test('a share code opens the crawl, uppercased', () {
      final t = WebLinks.crawl('ab12cd34', null)!;
      expect(t.isInvite, isFalse);
      expect(t.code, 'AB12CD34');
    });

    test('a valid ?crew= opens the crew invite', () {
      final t = WebLinks.crawl('AB12CD34', 'ab12cd34ef')!;
      expect(t.isInvite, isTrue);
      expect(t.code, 'AB12CD34EF');
    });

    test('a broken ?crew= falls back to the crawl', () {
      final t = WebLinks.crawl('AB12CD34', 'nope')!;
      expect(t.isInvite, isFalse);
      expect(t.code, 'AB12CD34');
    });

    test('an invalid share code with no crew is not a link', () {
      expect(WebLinks.crawl('ABC123', null), isNull);
      expect(WebLinks.crawl('ZZZZZZZZ', null), isNull);
      // A 10-char invite in the path is not a share code.
      expect(WebLinks.crawl('AB12CD34EF', null), isNull);
      expect(WebLinks.crawl(null, null), isNull);
    });
  });

  testWidgets('an unknown path lands on LinkNotFoundPage with a way Home', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/nope/at/all',
      errorBuilder: (context, state) => const LinkNotFoundPage(),
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('This link doesn’t open anything'), findsOneWidget);
    await tester.tap(find.text('Go to Home'));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
