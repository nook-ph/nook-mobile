import 'package:equatable/equatable.dart';

class CafeFilter extends Equatable {
  final Set<String> tagNames;
  final String sort;
  final String? query;
  final double? lat;
  final double? lng;

  const CafeFilter({
    this.tagNames = const {},
    this.sort = 'nearby',
    this.query,
    this.lat,
    this.lng,
  });

  CafeFilter copyWith({
    Set<String>? tagNames,
    String? sort,
    String? query,
    double? lat,
    double? lng,
  }) {
    return CafeFilter(
      tagNames: tagNames ?? this.tagNames,
      sort: sort ?? this.sort,
      query: query ?? this.query,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  @override
  List<Object?> get props => [tagNames, sort, query, lat, lng];
}
