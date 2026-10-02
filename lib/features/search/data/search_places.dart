import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/features/search/domain/search_place_index.dart';
import 'package:nook/features/search/domain/use_cases/search_cafes_usecase.dart';

/// The places a search can be measured from, built once per app session from
/// the listed cafes and shared by search and the map.
class SearchPlaces {
  SearchPlaces(this._searchCafes);

  final SearchCafesUseCase _searchCafes;
  Future<SearchPlaceIndex>? _index;

  /// `get_cafes` rejects a page longer than this.
  static const pageSize = 100;

  /// Stops a server that never returns a short page from looping forever.
  static const _maxPages = 20;

  Future<SearchPlaceIndex> index() {
    return _index ??= _allCafes().then(SearchPlaceIndex.fromCafes).catchError((
      Object e,
    ) {
      _index = null;
      throw e;
    });
  }

  /// Every listed cafe, a page at a time. By name, so the order holds still
  /// between pages; by id, so a cafe that straddles two pages counts once.
  Future<Iterable<CafeSummary>> _allCafes() async {
    final cafes = <String, CafeSummary>{};
    for (var page = 0; page < _maxPages; page++) {
      final batch = await _searchCafes.call(
        CafeQuery(sort: 'name', page: page, limit: pageSize),
      );
      for (final cafe in batch) {
        cafes[cafe.id] = cafe;
      }
      if (batch.length < pageSize) break;
    }
    return cafes.values;
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
