import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';

/// A cafe's tags split into the three groups the details page shows.
///
/// Categories arrive spelled several ways ("best_for", "Best For"), and some
/// listings have payment tags with no category at all, so the split tolerates
/// both.
class CafeTagGroups {
  const CafeTagGroups({
    required this.amenities,
    required this.bestFor,
    required this.payments,
  });

  final List<TagEntity> amenities;
  final List<TagEntity> bestFor;
  final List<TagEntity> payments;

  factory CafeTagGroups.from(List<TagEntity> tags) {
    final amenities = _byCategory(tags, const ['amenities', 'amenity']);
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
      };
      bestFor = tags.where((t) => !taken.contains(t.id)).toList();
    }

    return CafeTagGroups(
      amenities: amenities,
      bestFor: bestFor,
      payments: payments,
    );
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
