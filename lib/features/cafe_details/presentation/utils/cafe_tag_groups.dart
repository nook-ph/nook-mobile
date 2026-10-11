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
