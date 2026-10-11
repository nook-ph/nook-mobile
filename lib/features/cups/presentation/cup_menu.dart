import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';

/// The cafe's menu as composer suggestions ("What did you order?"), one per
/// name, each with a kind guessed from its category or name.
List<CupMenuOption> cupMenuFrom(Iterable<MenuItemEntity> items) {
  final seen = <String>{};
  return [
    for (final item in items)
      if (item.name.trim().isNotEmpty &&
          seen.add(item.name.trim().toLowerCase()))
        CupMenuOption(
          id: item.id,
          name: item.name.trim(),
          kind: guessCupKind(item.categoryName, item.name),
        ),
  ];
}

const _notCoffee = [
  'non-coffee', 'non coffee', 'matcha', 'chai', 'tea', 'chocolate', 'cocoa', //
];
const _coffeeWords = [
  'coffee', 'espresso', 'latte', 'americano', 'cappuccino', 'mocha', //
  'macchiato', 'cortado', 'flat white', 'brew', 'pour', 'v60', 'barako',
];
const _drinkWords = [
  'tea', 'matcha', 'chocolate', 'cocoa', 'juice', 'smoothie', 'soda', //
  'lemonade', 'frappe', 'milk', 'non-coffee', 'beverage', 'drink', 'shake',
];
const _foodWords = [
  'food', 'pastr', 'bread', 'cake', 'cookie', 'croissant', 'sandwich', //
  'pasta', 'rice', 'meal', 'breakfast', 'brunch', 'dessert', 'snack',
  'waffle', 'pancake', 'toast', 'salad', 'burger', 'pizza', 'muffin',
];

/// Coffee, another drink or food, from the item name (first) or its menu
/// category. Null when nothing says.
CupItemKind? guessCupKind(String? category, String name) {
  for (final text in [name, category]) {
    final t = text?.toLowerCase() ?? '';
    if (t.isEmpty) continue;
    // "Non-coffee" and "Matcha latte" are drinks before "coffee" or
    // "latte" can match.
    if (_notCoffee.any(t.contains)) return CupItemKind.drink;
    if (_coffeeWords.any(t.contains)) return CupItemKind.coffee;
    if (_drinkWords.any(t.contains)) return CupItemKind.drink;
    if (_foodWords.any(t.contains)) return CupItemKind.food;
  }
  return null;
}
