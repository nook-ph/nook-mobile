import 'package:equatable/equatable.dart';

class CafeFilter extends Equatable {
  final Set<String> tagNames;
  final String sort;
  final String? query;
  final double? lat;
  final double? lng;

  /// Keep only cafes open right now. Applied on the device to the fetched
  /// rows (the map RPCs return hours; none takes an open-now parameter).
  final bool openNow;

  const CafeFilter({
    this.tagNames = const {},
    this.sort = 'nearby',
    this.query,
    this.lat,
    this.lng,
    this.openNow = false,
  });

  CafeFilter copyWith({
    Set<String>? tagNames,
    String? sort,
    String? query,
    double? lat,
    double? lng,
    bool? openNow,
  }) {
    return CafeFilter(
      tagNames: tagNames ?? this.tagNames,
      sort: sort ?? this.sort,
      query: query ?? this.query,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      openNow: openNow ?? this.openNow,
    );
  }

  @override
  List<Object?> get props => [tagNames, sort, query, lat, lng, openNow];
}
