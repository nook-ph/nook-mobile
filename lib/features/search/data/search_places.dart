import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/features/search/domain/search_place_index.dart';
import 'package:nook/features/search/domain/use_cases/search_cafes_usecase.dart';

/// The places a search can be measured from, built once per app session from
/// the listed cafes and shared by search and the map.
class SearchPlaces {
  SearchPlaces(this._searchCafes);

  final SearchCafesUseCase _searchCafes;
  Future<SearchPlaceIndex>? _index;

  Future<SearchPlaceIndex> index() {
    return _index ??= _searchCafes
        .call(const CafeQuery(sort: 'top_rated', limit: 500))
        .then(SearchPlaceIndex.fromCafes)
        .catchError((Object e) {
          _index = null;
          throw e;
        });
  }

  /// "Lahug, Cebu City" under "Current location", when the phone's position
  /// is near a neighbourhood Nook knows. Only if the places load quickly.
  Future<String?> currentLocationLabel() async {
    final position = DeviceLocation.instance.position.value;
    if (position == null) return null;
    try {
      final places = await index().timeout(const Duration(milliseconds: 300));
      return places.nearest(position.latitude, position.longitude)?.fullLabel;
    } catch (_) {
      return null;
    }
  }
}
