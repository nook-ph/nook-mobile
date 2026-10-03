import 'package:nook/features/search/presentation/widgets/search_filters.dart';

/// Everyday words for each filter, so a search for "wifi" or "study" can be
/// answered with the filter that means it. Text search only compares cafe
/// names and descriptions, so these words found nothing, or a cafe 44 km
/// away (docs/ux/find-a-cafe.md, finding 1).
const Map<String, List<String>> _synonyms = {
  'Free WiFi': ['wifi', 'wi-fi', 'wi fi', 'internet'],
  'Power Outlets': [
    'outlet',
    'outlets',
    'plug',
    'socket',
    'charging',
    'charge',
  ],
  'Solo Work / Study': [
    'study',
    'studying',
    'work',
    'working',
    'laptop',
    'remote',
    'wfh',
  ],
  'Student Friendly': ['student', 'students', 'school', 'cheap'],
  'Air Conditioned': ['aircon', 'air con', 'ac', 'airconditioned', 'cool'],
  'Group Hangout': ['group', 'groups', 'barkada', 'friends', 'hangout'],
  'Date Spot': ['date', 'dating', 'romantic'],
  'Late Night': ['late', 'night', 'midnight'],
  'Open 24 Hours': ['24 hours', '24/7', '24h', 'all night'],
  'Outdoor Seating': ['outdoor', 'outside', 'al fresco', 'garden'],
  'Parking Available': ['parking', 'park'],
  'Pet Friendly': ['pet', 'pets', 'dog', 'dogs', 'cat'],
  'Book Cafe': ['book', 'books', 'reading'],
  'Nature Cafe': ['nature', 'mountain', 'view'],
  'Aesthetic / IG-worthy': ['aesthetic', 'instagram', 'ig', 'pretty'],
  'Specialty Coffee': ['specialty', 'third wave', 'pour over', 'pourover'],
  'Quick Coffee': ['quick', 'grab and go', 'to go'],
  'Takeaway Available': ['takeaway', 'take away', 'take out', 'takeout'],
  'Private Rooms': ['private', 'room', 'meeting'],
  'Wheelchair Accessible': ['wheelchair', 'accessible', 'pwd'],
  'Family Friendly': ['family', 'kids', 'children'],
};

/// Every filter the search sheet offers, Best for first.
const List<String> kSearchAllTags = [
  ...kSearchAllBestFor,
  ...kSearchAllAmenities,
];

/// The filters a typed [query] means, best match first, at most [max].
/// A filter matches when one of its words is the query, starts with it (at
/// three letters or more), or the query is part of the filter's own name.
List<String> searchTagsFor(String query, {int max = 2}) {
  final q = query.trim().toLowerCase();
  if (q.length < 2) return const [];
  final scored = <(String, int)>[];
  for (final tag in kSearchAllTags) {
    final name = tag.toLowerCase();
    final words = _synonyms[tag] ?? const <String>[];
    var score = 0;
    if (words.contains(q) || name == q) {
      score = 3;
    } else if (q.length >= 3 &&
        (words.any((w) => w.startsWith(q)) || name.startsWith(q))) {
      score = 2;
    } else if (q.length >= 3 && name.contains(q)) {
      score = 1;
    }
    if (score > 0) scored.add((tag, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final s in scored.take(max)) s.$1];
}
