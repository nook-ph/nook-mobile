import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_tags_page.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_tag_groups.dart';
import 'package:nook/utils/theme/theme.dart';

TagEntity _t(String name, String category) =>
    TagEntity(id: name, name: name, category: category);

Widget _host(CafeTagGroups groups, {double textScale = 1}) => MediaQuery(
  data: MediaQueryData(
    size: const Size(390, 844),
    textScaler: TextScaler.linear(textScale),
  ),
  child: MaterialApp(
    theme: TAppTheme.lightTheme,
    home: CafeTagsPage(groups: groups, cafeName: 'Tadaima'),
  ),
);

void main() {
  testWidgets('Coffee first, each coffee tag with its line', (tester) async {
    await tester.pumpWidget(
      _host(
        CafeTagGroups.from([
          _t('Free WiFi', 'amenities'),
          _t('Pour-over', 'coffee'),
          _t('Specialty Coffee', 'best_for'),
          _t('Date Spot', 'best_for'),
        ]),
      ),
    );

    expect(find.text('What this cafe offers'), findsOneWidget);
    expect(find.text('Tadaima'), findsOneWidget);
    final coffeeY = tester.getTopLeft(find.text('Coffee')).dy;
    expect(coffeeY, lessThan(tester.getTopLeft(find.text('Best for')).dy));
    expect(
      tester.getTopLeft(find.text('Best for')).dy,
      lessThan(tester.getTopLeft(find.text('Amenities')).dy),
    );
    expect(find.text('Filter coffee hand-brewed to order'), findsOneWidget);
    expect(
      find.text('Named beans, roast dates and trained baristas'),
      findsOneWidget,
    );
    // No lines outside Coffee.
    expect(find.text('Date Spot'), findsOneWidget);
    expect(find.text('Payment'), findsNothing);
  });

  testWidgets('before the coffee tags: no Coffee group, no lines', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CafeTagGroups.from([
          _t('Specialty Coffee', 'best_for'),
          _t('Free WiFi', 'amenities'),
          _t('Cash', 'payment'),
        ]),
      ),
    );

    expect(find.text('Coffee'), findsNothing);
    expect(find.text('Specialty Coffee'), findsOneWidget);
    expect(
      find.text('Named beans, roast dates and trained baristas'),
      findsNothing,
    );
    expect(find.text('Payment'), findsOneWidget);
  });

  testWidgets('long names and the largest text do not overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CafeTagGroups.from([
          for (final name in const [
            'Espresso',
            'Kapeng Barako',
            'Roasts In-House',
          ])
            _t(name, 'coffee'),
          _t('Aesthetic / IG-worthy', 'best_for'),
          _t('Reservations Accepted', 'amenities'),
          _t('Wheelchair Accessible', 'amenities'),
        ]),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Wheelchair Accessible'), 200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back pops the page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TAppTheme.lightTheme,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CafeTagsPage(
                  groups: CafeTagGroups.from([_t('Free WiFi', 'amenities')]),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(CafeTagsPage), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(CafeTagsPage), findsNothing);
  });
}
