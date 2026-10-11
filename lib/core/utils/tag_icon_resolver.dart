import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Nook's own coffee icons (nook-supabase `assets/icons/coffee/`, the
/// `nook:<file>` values of `tags.icon_name`). Drawn by `CoffeeGlyphIcon`.
enum CoffeeGlyph {
  espresso,
  pourOver,
  coldBrew,
  philippineBeans,
  kapengBarako,
  matcha,
}

/// The coffee tags, in the order the contract sorts them (docs
/// COFFEE_TAGS.md). `tags.name` is the key, so these are exact names.
const kCoffeeTagNames = [
  'Espresso',
  'Pour-over',
  'Cold Brew',
  'Slow Bar',
  'Single Origin',
  'Philippine Beans',
  'Kapeng Barako',
  'Roasts In-House',
  'Matcha',
];

/// The custom glyph for a coffee tag, keyed by tag name like
/// [resolveTagIcon]. Null for every tag that uses a Phosphor icon.
CoffeeGlyph? resolveCoffeeGlyph(String? tagName) {
  if (tagName == null) return null;
  return switch (tagName.trim().toLowerCase()) {
    'espresso' => CoffeeGlyph.espresso,
    'pour-over' => CoffeeGlyph.pourOver,
    'cold brew' => CoffeeGlyph.coldBrew,
    'philippine beans' => CoffeeGlyph.philippineBeans,
    'kapeng barako' => CoffeeGlyph.kapengBarako,
    'matcha' => CoffeeGlyph.matcha,
    _ => null,
  };
}

/// Whether the tag has any icon, custom or Phosphor.
bool hasTagIcon(String? tagName) =>
    resolveCoffeeGlyph(tagName) != null || resolveTagIcon(tagName) != null;

/// The Phosphor icon for a tag. Coffee tags drawn by Nook itself return null
/// here; render tags with `TagIcon`, which checks [resolveCoffeeGlyph] first.
IconData? resolveTagIcon(String? tagName) {
  if (tagName == null || tagName.trim().isEmpty) {
    return null;
  }

  final name = tagName.trim().toLowerCase();

  switch (name) {
    case 'date spot':
      return PhosphorIcons.heart();
    case 'solo work / study':
      return PhosphorIcons.laptop();
    case 'community space':
      return PhosphorIcons.usersThree();
    case 'group hangout':
    case 'family friendly':
      return PhosphorIcons.users();
    case 'book cafe':
      return PhosphorIcons.bookOpen();
    case 'late night':
      return PhosphorIcons.moon();
    case 'quick coffee':
    case 'specialty coffee':
      return PhosphorIcons.coffee();
    case 'nature cafe':
      return PhosphorIcons.leaf();
    case 'special occasion':
      return PhosphorIcons.sparkle();
    case 'student friendly':
      return PhosphorIcons.graduationCap();
    case 'aesthetic / ig-worthy':
      return PhosphorIcons.instagramLogo();
    case 'pet friendly':
      return PhosphorIcons.dog();
    case 'free wifi':
      return PhosphorIcons.wifiHigh();
    case 'power outlets':
      return PhosphorIcons.plug();
    case 'air conditioned':
      return PhosphorIcons.snowflake();
    case 'outdoor seating':
      return PhosphorIcons.chair();
    case 'parking available':
      return PhosphorIcons.letterCircleP();
    case 'reservations accepted':
      return PhosphorIcons.calendarCheck();
    case 'private rooms':
      return PhosphorIcons.doorOpen();
    case 'wheelchair accessible':
      return PhosphorIcons.wheelchair();
    case 'takeaway available':
      return PhosphorIcons.shoppingBag();
    case 'smoking area':
      return PhosphorIcons.cigarette();
    case 'open 24 hours':
      return PhosphorIcons.clock();
    case 'slow bar':
      return PhosphorIcons.hourglassMedium();
    case 'single origin':
      return PhosphorIcons.coffeeBean();
    case 'roasts in-house':
      return PhosphorIcons.fire();
    default:
      if (name.contains('wifi')) return PhosphorIcons.wifiHigh();
      if (name.contains('cash')) return PhosphorIcons.money();
      if (name.contains('card') ||
          name.contains('credit') ||
          name.contains('debit')) {
        return PhosphorIcons.creditCard();
      }
      if (name.contains('wallet') ||
          name.contains('gcash') ||
          name.contains('maya')) {
        return PhosphorIcons.wallet();
      }
      return null;
  }
}
