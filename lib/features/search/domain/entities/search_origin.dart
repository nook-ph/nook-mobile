import 'package:equatable/equatable.dart';

enum SearchOriginKind {
  place,
  pin,

  /// One of the user's saved places ("Home", "Lola's house").
  saved,
}

/// Where search measures distances from when it is not the phone's location:
/// a place picked from the list, a saved place, or a pin dropped on the map.
class SearchOrigin extends Equatable {
  const SearchOrigin({
    required this.label,
    this.subtitle,
    required this.lat,
    required this.lng,
    this.kind = SearchOriginKind.place,
  });

  /// A dropped pin, named after what it landed [near] ("Near Ayala Center
  /// Cebu", "Lahug, Cebu City"), or "Pinned location" when nothing is known.
  const SearchOrigin.pin({
    required this.lat,
    required this.lng,
    String? near,
    this.subtitle,
  }) : label = near ?? pinnedLabel,
       kind = SearchOriginKind.pin;

  static const pinnedLabel = 'Pinned location';

  final String label;
  final String? subtitle;
  final double lat;
  final double lng;
  final SearchOriginKind kind;

  bool get isPin => kind == SearchOriginKind.pin;

  bool get isSaved => kind == SearchOriginKind.saved;

  /// "IT Park, Cebu City" for the "Near …" row. A saved place is its name
  /// alone: "Near Home".
  String get fullLabel {
    final sub = subtitle?.trim() ?? '';
    if (isPin || isSaved || sub.isEmpty || label.contains(sub)) return label;
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
      kind: SearchOriginKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => SearchOriginKind.place,
      ),
    );
  }

  @override
  List<Object?> get props => [label, subtitle, lat, lng, kind];
}
