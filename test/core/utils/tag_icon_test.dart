import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/presentation/widgets/tag_icon.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('coffee tag icons', () {
    test('every coffee tag has an icon', () {
      expect(kCoffeeTagNames, hasLength(9));
      for (final name in kCoffeeTagNames) {
        expect(hasTagIcon(name), isTrue, reason: name);
      }
    });

    test('six are drawn by Nook, keyed by name in any case', () {
      expect(resolveCoffeeGlyph('Espresso'), CoffeeGlyph.espresso);
      expect(resolveCoffeeGlyph('pour-over'), CoffeeGlyph.pourOver);
      expect(resolveCoffeeGlyph(' Cold Brew '), CoffeeGlyph.coldBrew);
      expect(
        resolveCoffeeGlyph('PHILIPPINE BEANS'),
        CoffeeGlyph.philippineBeans,
      );
      expect(resolveCoffeeGlyph('Kapeng Barako'), CoffeeGlyph.kapengBarako);
      expect(resolveCoffeeGlyph('Matcha'), CoffeeGlyph.matcha);
      expect(resolveTagIcon('Matcha'), isNull);
    });

    test('three are Phosphor icons', () {
      expect(resolveTagIcon('Slow Bar'), PhosphorIcons.hourglassMedium());
      expect(resolveTagIcon('Single Origin'), PhosphorIcons.coffeeBean());
      expect(resolveTagIcon('Roasts In-House'), PhosphorIcons.fire());
      expect(resolveCoffeeGlyph('Slow Bar'), isNull);
    });

    test('other tags are unchanged', () {
      expect(resolveCoffeeGlyph('Specialty Coffee'), isNull);
      expect(resolveTagIcon('Specialty Coffee'), PhosphorIcons.coffee());
      expect(hasTagIcon('Something new'), isFalse);
    });
  });

  group('TagIcon', () {
    testWidgets('draws a custom glyph at the asked size', (tester) async {
      await tester.pumpWidget(
        _host(const TagIcon('Kapeng Barako', size: 18, color: Colors.black)),
      );

      expect(find.byType(CoffeeGlyphIcon), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(tester.getSize(find.byType(CoffeeGlyphIcon)), const Size(18, 18));
    });

    testWidgets('falls back to the Phosphor icon', (tester) async {
      await tester.pumpWidget(
        _host(const TagIcon('Free WiFi', size: 18, color: Colors.black)),
      );

      expect(find.byType(CoffeeGlyphIcon), findsNothing);
      expect(find.byIcon(PhosphorIcons.wifiHigh()), findsOneWidget);
    });

    testWidgets('renders nothing, or the fallback, for an unknown tag', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const TagIcon('Unknown', size: 18, color: Colors.black)),
      );
      expect(find.byType(Icon), findsNothing);

      await tester.pumpWidget(
        _host(
          const TagIcon(
            'Unknown',
            size: 18,
            color: Colors.black,
            fallback: Icons.circle_outlined,
          ),
        ),
      );
      expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
    });

    testWidgets('every glyph paints without error', (tester) async {
      await tester.pumpWidget(
        _host(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final glyph in CoffeeGlyph.values)
                CoffeeGlyphIcon(glyph, size: 24, color: Colors.black),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(CoffeeGlyphIcon), findsNWidgets(6));
    });
  });
}
