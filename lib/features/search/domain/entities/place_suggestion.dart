import 'package:equatable/equatable.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';

/// What sort of place a suggestion is, for its icon.
enum PlaceType {
  /// A neighbourhood or city Nook knows from its own cafes.
  nookArea,

  /// A city, district or barangay from the map.
  area,
  street,

  /// A landmark: a mall, a campus, a park.
  landmark,
  address;

  static PlaceType fromKind(String? kind) => switch (kind) {
    'area' => PlaceType.area,
    'street' => PlaceType.street,
    'address' => PlaceType.address,
    _ => PlaceType.landmark,
  };
}

/// One row in the place results: where it is, and what kind of place.
class PlaceSuggestion extends Equatable {
  const PlaceSuggestion(this.origin, this.type);

  final SearchOrigin origin;
  final PlaceType type;

  bool get fromNook => type == PlaceType.nookArea;

  @override
  List<Object?> get props => [origin, type];
}
