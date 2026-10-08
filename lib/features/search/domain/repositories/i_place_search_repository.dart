import 'package:nook/features/search/domain/entities/place_suggestion.dart';

/// Looks places up by name and names a spot on the map. The server decides
/// which geocoder answers; the app only sees Nook's shape.
abstract class IPlaceSearchRepository {
  /// Places matching [query], nearest [lat],[lng] first when given.
  ///
  /// Throws [PlaceSearchUnavailable] when the service cannot answer right
  /// now (busy, offline, rate-limited).
  Future<PlaceSearchResult> search(String query, {double? lat, double? lng});

  /// The place that best names the spot, or null when nothing is near.
  Future<PlaceSuggestion?> reverse(double lat, double lng);
}

class PlaceSearchResult {
  const PlaceSearchResult(this.places, {this.attribution});

  final List<PlaceSuggestion> places;

  /// "© OpenStreetMap contributors": shown under results from the map.
  final String? attribution;
}

class PlaceSearchUnavailable implements Exception {
  const PlaceSearchUnavailable([this.reason]);

  final String? reason;

  @override
  String toString() => 'PlaceSearchUnavailable($reason)';
}
