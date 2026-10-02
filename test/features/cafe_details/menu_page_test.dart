import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/pages/menu_full_page.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_category_section.dart';

MenuItemEntity _item(
  String name,
  double price, {
  String? category,
  List<MenuItemVariantEntity> variants = const [],
}) => MenuItemEntity(
  id: name,
  cafeId: 'cafe',
  name: name,
  price: price,
  isHighlight: false,
  categoryName: category,
  variants: variants,
);

void main() {
  group('menuPriceLabel', () {
    test('plain item shows its price', () {
      expect(menuPriceLabel(_item('Americano', 110)), '₱110.00');
    });

    test('sizes at different prices read "from" the cheapest', () {
      final item = _item(
        'Latte',
        150,
        variants: const [
          MenuItemVariantEntity(id: 'r', label: 'Regular'),
          MenuItemVariantEntity(id: 'l', label: 'Large', priceModifier: 30),
        ],
      );
      expect(menuPriceLabel(item), 'from ₱150.00');
    });

    test('sizes at one price drop the "from"', () {
      final item = _item(
        'Tea',
        90,
        variants: const [
          MenuItemVariantEntity(id: 'h', label: 'Hot'),
          MenuItemVariantEntity(id: 'i', label: 'Iced'),
        ],
      );
      expect(menuPriceLabel(item), '₱90.00');
    });
  });

  group('groupMenuByCategory', () {
    test('keeps first-seen order and files blanks under Others', () {
      final grouped = groupMenuByCategory([
        _item('A', 1, category: 'Coffee'),
        _item('B', 1),
        _item('C', 1, category: 'Pastries'),
        _item('D', 1, category: 'Coffee'),
        _item('E', 1, category: '  '),
      ]);
      expect(grouped.keys.toList(), ['Coffee', 'Others', 'Pastries']);
      expect(grouped['Coffee']!.map((i) => i.name), ['A', 'D']);
      expect(grouped['Others']!.map((i) => i.name), ['B', 'E']);
    });
  });

  group('MenuFullPage', () {
    Future<void> pump(WidgetTester tester, List<MenuItemEntity> items) {
      return tester.pumpWidget(
        MaterialApp(
          home: MenuFullPage(menuItems: items, cafeName: 'Tadaima'),
        ),
      );
    }

    testWidgets('empty menu shows the empty copy and no chips', (tester) async {
      await pump(tester, const []);
      expect(find.text('No menu posted yet'), findsOneWidget);
      expect(find.text('Tadaima'), findsOneWidget);
    });

    testWidgets('lists categories, chips and prices', (tester) async {
      await pump(tester, [
        _item('Americano', 110, category: 'Coffee'),
        _item('Croissant', 95, category: 'Pastries'),
      ]);
      // Once as a chip, once as the section heading.
      expect(find.text('Coffee'), findsNWidgets(2));
      expect(find.text('Pastries'), findsNWidgets(2));
      expect(find.text('₱110.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a single category has no jump bar', (tester) async {
      await pump(tester, [_item('Americano', 110, category: 'Coffee')]);
      expect(find.text('Coffee'), findsOneWidget);
    });

    testWidgets('a long name wraps without overflowing at 360pt', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(tester, [
        _item(
          'Iced Brown Sugar Oat Milk Shaken Espresso with Sea Salt Cream',
          150,
          category: 'Coffee',
          variants: const [
            MenuItemVariantEntity(id: 'r', label: 'Regular'),
            MenuItemVariantEntity(id: 'l', label: 'Large', priceModifier: 30),
          ],
        ),
      ]);
      expect(find.text('from ₱150.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping an item with sizes opens the sizes sheet', (
      tester,
    ) async {
      await pump(tester, [
        _item(
          'Latte',
          150,
          category: 'Coffee',
          variants: const [
            MenuItemVariantEntity(id: 'r', label: 'Regular', isDefault: true),
            MenuItemVariantEntity(id: 'l', label: 'Large', priceModifier: 30),
          ],
        ),
      ]);
      await tester.tap(find.text('Latte'));
      await tester.pumpAndSettle();
      expect(find.text('Default'), findsOneWidget);
      expect(find.text('₱180.00'), findsOneWidget);
    });
  });
}
