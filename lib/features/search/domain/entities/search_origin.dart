import 'package:equatable/equatable.dart';

enum SearchOriginKind { place, pin }

/// Where search measures distances from when it is not the phone's location:
/// a place picked from the list, or a pin dropped on the map.
class SearchOrigin extends Equatable {
  const SearchOrigin({
    required this.label,
    this.subtitle,
    required this.lat,
    required this.lng,
    this.kind = SearchOriginKind.place,
  });

  /// A dropped pin. There is no reverse geocoding, so it is named after the
  /// neighbourhood it landed [near] when Nook knows one, and "Pinned
  /// location" otherwise.
  const SearchOrigin.pin({required this.lat, required this.lng, String? near})
    : label = near ?? pinnedLabel,
      subtitle = null,
      kind = SearchOriginKind.pin;

  static const pinnedLabel = 'Pinned location';

  final String label;
  final String? subtitle;
  final double lat;
  final double lng;
  final SearchOriginKind kind;

  bool get isPin => kind == SearchOriginKind.pin;

  /// "IT Park, Cebu City" for the "Near …" row.
  String get fullLabel {
    final sub = subtitle?.trim() ?? '';
    if (isPin || sub.isEmpty || label.contains(sub)) return label;
    return '$label, $sub';
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'subtitle': subtitle,
    'lat': lat,
    'lng': lng,
    'kind': kind.name,
  };

  static SearchOrigin? fromJson(Object? json) {
    if (json is! Map) return null;
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    final label = json['label'] as String?;
    if (lat == null || lng == null || label == null || label.isEmpty) {
      return null;
    }
    return SearchOrigin(
      label: label,
      subtitle: json['subtitle'] as String?,
      lat: lat,
      lng: lng,
      kind: json['kind'] == SearchOriginKind.pin.name
          ? SearchOriginKind.pin
          : SearchOriginKind.place,
    );
  }

  @override
  List<Object?> get props => [label, subtitle, lat, lng, kind];
}
