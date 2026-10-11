import 'dart:math' as math;

import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

/// A cafe's tags split into the groups the details page shows.
///
/// Categories arrive spelled several ways ("best_for", "Best For"), and some
/// listings have payment tags with no category at all, so the split tolerates
/// both.
class CafeTagGroups {
  const CafeTagGroups({
    required this.amenities,
    required this.bestFor,
    required this.payments,
    this.coffee = const [],
  });

  final List<TagEntity> amenities;
  final List<TagEntity> bestFor;
  final List<TagEntity> payments;

  /// The `coffee` category (docs COFFEE_TAGS.md), in the contract's order.
  /// When there is any, Specialty Coffee leads it instead of sitting in Best
  /// for: it is still a `best_for` tag, only shown here. Empty until the
  /// coffee tags exist, and the page then looks as it did before them.
  final List<TagEntity> coffee;

  /// The name Specialty Coffee keeps in `best_for` (admin-only there).
  static const specialtyCoffee = 'Specialty Coffee';

  factory CafeTagGroups.from(List<TagEntity> tags) {
    final amenities = _byCategory(tags, const ['amenities', 'amenity']);
    final coffee = _inContractOrder(_byCategory(tags, const ['coffee']));
    var bestFor = _byCategory(tags, const [
      'best_for',
      'best for',
      'bestfor',
      'best',
    ]);
    var payments = _byCategory(tags, const [
      'payment_options',
      'payment option',
      'payment options',
      'payment',
      'payments',
      'accepted payment',
      'accepted payments',
    ]);

    if (payments.isEmpty) {
      payments = tags.where(_looksLikePayment).toList();
    }

    // Uncategorised tags read as "best for" rather than being dropped.
    if (bestFor.isEmpty) {
      final taken = <String>{
        ...amenities.map((t) => t.id),
        ...payments.map((t) => t.id),
        ...coffee.map((t) => t.id),
      };
      bestFor = tags.where((t) => !taken.contains(t.id)).toList();
    }

    if (coffee.isNotEmpty) {
      bool isSpecialty(TagEntity t) =>
          _normalize(t.name) == _normalize(specialtyCoffee);
      final specialty = bestFor.where(isSpecialty).toList();
      if (specialty.isNotEmpty) {
        coffee.insert(0, specialty.first);
        bestFor = bestFor.where((t) => !isSpecialty(t)).toList();
      }
    }

    return CafeTagGroups(
      amenities: amenities,
      bestFor: bestFor,
      payments: payments,
      coffee: coffee,
    );
  }

  /// How many tags the cafe has in all, the N of "See all N".
  int get total =>
      coffee.length + bestFor.length + amenities.length + payments.length;

  /// The groups as the all-tags page titles and orders them: Coffee, Best
  /// for (the cafe's featured ones first), Amenities (the ones people check
  /// first, [amenityPriority]), Payment. Empty groups are left out unless
  /// [includeEmpty].
  List<({String title, List<TagEntity> tags})> sections({
    bool includeEmpty = false,
  }) => [
    (title: 'Coffee', tags: coffee),
    (
      title: 'Best for',
      tags: [
        ...bestFor.where((t) => t.isFeatured),
        ...bestFor.where((t) => !t.isFeatured),
      ],
    ),
    (title: 'Amenities', tags: _byPriority(amenities)),
    (title: 'Payment', tags: payments),
  ].where((s) => includeEmpty || s.tags.isNotEmpty).toList();

  /// How many tags the details page previews before "See all".
  ///
  /// Cafes carry a median of 10 tags and up to 23 (prod, before the coffee
  /// tags add up to 10 more). Six is two rows of the two-column grid per
  /// group, and leaves most cafes with a short "See all".
  static const previewCap = 6;

  /// The tags the details page shows before "See all": up to two each from
  /// Coffee, Best for and Amenities, in that order. A group with fewer gives
  /// its places to the others (Coffee, then Best for, then Amenities, then
  /// Payment). Best for leads with the cafe's featured tags; Amenities with
  /// the ones people come to work for ([amenityPriority]).
  ///
  /// When the cafe has [cap] tags or fewer, this is all of them.
  List<TagEntity> preview({int cap = previewCap}) {
    final ranked = [for (final s in sections(includeEmpty: true)) s.tags];
    const perGroup = 2;
    // Each of the first three groups gets its share...
    final quota = [
      for (var i = 0; i < ranked.length; i++)
        i < 3 ? math.min<int>(perGroup, ranked[i].length) : 0,
    ];
    // ...and places left over go to what is left, in group order.
    var left = cap - quota.fold<int>(0, (a, b) => a + b);
    for (var i = 0; i < ranked.length && left > 0; i++) {
      final more = math.min<int>(left, ranked[i].length - quota[i]);
      quota[i] += more;
      left -= more;
    }
    return [
      for (var i = 0; i < ranked.length; i++) ...ranked[i].take(quota[i]),
    ].take(cap).toList();
  }

  /// One line a customer can read under a coffee tag on the all-tags page,
  /// from the tick-it-when criteria in COFFEE_TAGS.md. Null for every other
  /// tag: amenities and Best for say what they mean on their own.
  static String? coffeeHint(String name) => _coffeeHints[_normalize(name)];

  static final _coffeeHints = {
    for (final e in const {
      specialtyCoffee: 'Named beans, roast dates and trained baristas',
      'Espresso': 'Shots pulled on an espresso machine',
      'Pour-over': 'Filter coffee hand-brewed to order',
      'Cold Brew': 'Coffee steeped cold for hours',
      'Slow Bar': 'A bar just for made-to-order manual brews',
      'Single Origin': 'Coffee from one named farm or region',
      'Philippine Beans': 'Coffee grown in the Philippines',
      'Kapeng Barako': 'Philippine Liberica, the strong local bean',
      'Roasts In-House': 'Roasts its own beans',
      'Matcha': 'Matcha drinks on the menu',
    }.entries)
      _normalize(e.key): e.value,
  };

  /// Amenities a cafe-goer checks first, most important first. Anything else
  /// keeps its listing order after these.
  static const amenityPriority = [
    'Free WiFi',
    'Power Outlets',
    'Air Conditioned',
    'Outdoor Seating',
    'Pet Friendly',
    'Parking Available',
  ];

  static List<TagEntity> _byPriority(List<TagEntity> tags) {
    int rank(TagEntity t) {
      final i = amenityPriority.indexWhere(
        (name) => _normalize(name) == _normalize(t.name),
      );
      return i < 0 ? amenityPriority.length : i;
    }

    // List.sort is not stable; sort by (rank, original index).
    final indexed = tags.indexed.toList()
      ..sort((a, b) {
        final r = rank(a.$2).compareTo(rank(b.$2));
        return r != 0 ? r : a.$1.compareTo(b.$1);
      });
    return [for (final (_, t) in indexed) t];
  }

  /// Known coffee tags in the contract's order, anything newer after them.
  static List<TagEntity> _inContractOrder(List<TagEntity> tags) {
    final known = [
      for (final name in kCoffeeTagNames)
        ...tags.where((t) => _normalize(t.name) == _normalize(name)),
    ];
    return [...known, ...tags.where((t) => !known.contains(t))];
  }

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  static List<TagEntity> _byCategory(
    List<TagEntity> tags,
    List<String> aliases,
  ) {
    final normalized = aliases.map(_normalize).toSet();
    return tags
        .where((tag) => normalized.contains(_normalize(tag.category ?? '')))
        .toList();
  }

  static bool _looksLikePayment(TagEntity tag) {
    final text = tag.name.toLowerCase();
    return text.contains('cash') ||
        text.contains('card') ||
        text.contains('credit') ||
        text.contains('debit') ||
        text.contains('wallet') ||
        text.contains('gcash') ||
        text.contains('maya');
  }
}
