import 'package:equatable/equatable.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';

enum SavedPlaceKind {
  home,
  work,
  custom;

  static SavedPlaceKind parse(Object? raw) => switch (raw) {
    'home' => SavedPlaceKind.home,
    'work' => SavedPlaceKind.work,
    _ => SavedPlaceKind.custom,
  };

  /// The name Home and Work always show. Custom places carry their own.
  String get presetLabel => switch (this) {
    SavedPlaceKind.home => 'Home',
    SavedPlaceKind.work => 'School or work',
    SavedPlaceKind.custom => '',
  };
}

/// A place the user named and kept, to search near in one tap. Private to
/// its owner: never shown on a profile.
class SavedPlace extends Equatable {
  const SavedPlace({
    this.id,
    required this.kind,
    required this.label,
    this.address,
    required this.lat,
    required this.lng,
  });

  /// Null until saved.
  final String? id;
  final SavedPlaceKind kind;

  /// "Home", "School or work", or the user's own name ("Lola's house").
  final String label;

  /// Where it is, in words: "Lahug, Cebu City".
  final String? address;
  final double lat;
  final double lng;

  static const maxLabelLength = 40;

  /// The search origin this place stands for. Same place, same origin, so
  /// the sheet can tick the one in use.
  SearchOrigin toOrigin() => SearchOrigin(
    label: label,
    subtitle: address,
    lat: lat,
    lng: lng,
    kind: SearchOriginKind.saved,
  );

  SavedPlace copyWith({
    String? id,
    SavedPlaceKind? kind,
    String? label,
    String? address,
    double? lat,
    double? lng,
  }) => SavedPlace(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    label: label ?? this.label,
    address: address ?? this.address,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'label': label,
    'address': address,
    'lat': lat,
    'lng': lng,
  };

  static SavedPlace? fromJson(Object? json) {
    if (json is! Map) return null;
    final lat = (json['lat'] as num?)?.toDouble();
    final lng = (json['lng'] as num?)?.toDouble();
    final label = json['label'] as String?;
    if (lat == null || lng == null || label == null || label.isEmpty) {
      return null;
    }
    return SavedPlace(
      id: json['id'] as String?,
      kind: SavedPlaceKind.parse(json['kind']),
      label: label,
      address: json['address'] as String?,
      lat: lat,
      lng: lng,
    );
  }

  @override
  List<Object?> get props => [id, kind, label, address, lat, lng];
}
