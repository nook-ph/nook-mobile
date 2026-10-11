import 'package:flutter/foundation.dart';
import 'package:nook/core/utils/tag_icon_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Which coffee tags (docs COFFEE_TAGS.md) exist in the database, so the
/// filter sheets only offer chips that can match something.
///
/// Until the coffee migration is applied there are none, [available] stays
/// empty and the sheets show no Coffee section, exactly as before. A failed
/// lookup counts as "none"; the next [ensureLoaded] tries again.
class CoffeeTagCatalog {
  CoffeeTagCatalog({Future<List<String>> Function()? fetch})
    : _fetch = fetch ?? _fetchActiveCoffeeTags;

  static final CoffeeTagCatalog instance = CoffeeTagCatalog();

  final Future<List<String>> Function() _fetch;

  /// The coffee filter labels that exist, in the contract's order.
  final ValueNotifier<List<String>> available = ValueNotifier(const []);

  Future<void>? _loading;

  /// Looks the tags up once; later calls reuse the answer.
  Future<void> ensureLoaded() => _loading ??= _load();

  Future<void> _load() async {
    try {
      available.value = coffeeFilterLabels(await _fetch());
    } catch (e) {
      debugPrint('CoffeeTagCatalog: lookup failed: $e');
      _loading = null;
    }
  }

  static Future<List<String>> _fetchActiveCoffeeTags() async {
    final rows = await Supabase.instance.client
        .from('tags')
        .select('name')
        .eq('category', 'coffee')
        .eq('is_active', true);
    return [for (final row in rows) row['name'] as String];
  }
}

/// The coffee chips to offer, given the coffee tag names in the database:
/// the contract's tags that are present, in its order. Tags the app has no
/// copy for yet are left out rather than shown unordered.
List<String> coffeeFilterLabels(Iterable<String> namesInDatabase) {
  final present = {for (final n in namesInDatabase) n.trim().toLowerCase()};
  return [
    for (final name in kCoffeeTagNames)
      if (present.contains(name.toLowerCase())) name,
  ];
}
