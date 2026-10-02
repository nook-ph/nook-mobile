import 'dart:math' as math;

import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';

/// Places a search can be measured from, built from the neighbourhoods and
/// cities of the cafes Nook already lists.
///
/// There is no geocoding service behind search, so "type a place" matches
/// against these instead: each neighbourhood (with its city underneath) and
/// each city, placed at the average position of its cafes.
class SearchPlaceIndex {
  SearchPlaceIndex._(this.places);

  final List<SearchOrigin> places;

  static final empty = SearchPlaceIndex._(const []);

  factory SearchPlaceIndex.fromCafes(Iterable<CafeSummary> cafes) {
    final groups = <String, _Acc>{};
    void add(
      String key,
      String label,
      String? subtitle,
      double lat,
      double lng,
    ) {
      (groups[key] ??= _Acc(label, subtitle)).add(lat, lng);
    }

    for (final cafe in cafes) {
      final lat = cafe.lat;
      final lng = cafe.lng;
      if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;
      final hood = cafe.neighborhood?.trim() ?? '';
      final city = cafe.city?.trim() ?? '';
      if (hood.isNotEmpty) {
        add(
          'n:${hood.toLowerCase()}|${city.toLowerCase()}',
          hood,
          city.isEmpty ? null : city,
          lat,
          lng,
        );
      }
      if (city.isNotEmpty) {
        add('c:${city.toLowerCase()}', city, null, lat, lng);
      }
    }

    final places =
        groups.values
            .map(
              (g) => SearchOrigin(
                label: g.label,
                subtitle: g.subtitle,
                lat: g.lat / g.count,
                lng: g.lng / g.count,
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
          );
    return SearchPlaceIndex._(places);
  }

  /// Places whose name or city contains [text], names that start with it
  /// first. Empty text matches nothing.
  List<SearchOrigin> match(String text, {int limit = 6}) {
    final q = text.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = places.where((p) {
      return p.label.toLowerCase().contains(q) ||
          (p.subtitle?.toLowerCase().contains(q) ?? false);
    }).toList();
    int rank(SearchOrigin p) {
      final label = p.label.toLowerCase();
      if (label.startsWith(q)) return 0;
      if (label.contains(q)) return 1;
      return 2;
    }

    hits.sort((a, b) => rank(a).compareTo(rank(b)));
    return hits.take(limit).toList();
  }

  /// The neighbourhood closest to a position, to name "Current location".
  /// Null when nothing is within [maxMeters].
  SearchOrigin? nearest(double lat, double lng, {double maxMeters = 3000}) {
    SearchOrigin? best;
    var bestDistance = double.infinity;
    for (final p in places) {
      if (p.subtitle == null) continue;
      final d = distanceMeters(lat, lng, p.lat, p.lng);
      if (d < bestDistance) {
        bestDistance = d;
        best = p;
      }
    }
    return bestDistance <= maxMeters ? best : null;
  }

  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }
}

class _Acc {
  _Acc(this.label, this.subtitle);

  final String label;
  final String? subtitle;
  double lat = 0;
  double lng = 0;
  int count = 0;

  void add(double la, double ln) {
    lat += la;
    lng += ln;
    count++;
  }
}
