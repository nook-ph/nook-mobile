import 'package:nook/features/search/domain/entities/place_suggestion.dart';
import 'package:nook/features/search/domain/repositories/i_place_search_repository.dart';
import 'package:nook/features/search/domain/search_place_index.dart';

/// A name for a spot on the map.
typedef SpotName = ({String label, String? subtitle});

/// Names a dropped pin: "Near Ayala Center Cebu" from the map service, else
/// the Nook neighbourhood it is in, else null ("Pinned location").
class SpotNamer {
  SpotNamer(this._repository, this._places);

  final IPlaceSearchRepository? _repository;
  final Future<SearchPlaceIndex>? _places;

  Future<SpotName?> name(double lat, double lng) async {
    final repo = _repository;
    if (repo != null) {
      try {
        final place = await repo.reverse(lat, lng);
        if (place != null) return labelFor(place);
      } catch (_) {
        // Busy or offline: fall back to Nook's own areas.
      }
    }
    try {
      final index = await _places;
      final near = index?.nearest(lat, lng);
      if (near != null) return (label: near.fullLabel, subtitle: null);
    } catch (_) {}
    return null;
  }

  /// An area names the spot itself ("Lahug, Cebu City"); a landmark or a
  /// street is something the spot is near ("Near SM Seaside City Cebu").
  static SpotName labelFor(PlaceSuggestion place) {
    final o = place.origin;
    if (place.type == PlaceType.area || place.type == PlaceType.nookArea) {
      return (label: o.fullLabel, subtitle: null);
    }
    return (label: 'Near ${o.label}', subtitle: o.subtitle);
  }
}
