import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/search_place_index.dart';

CafeSummary _cafe(
  String id,
  String? hood,
  String? city,
  double lat,
  double lng,
) => CafeSummary(
  id: id,
  name: 'Cafe $id',
  neighborhood: hood,
  city: city,
  rating: 4,
  lat: lat,
  lng: lng,
);

void main() {
  final index = SearchPlaceIndex.fromCafes([
    _cafe('1', 'IT Park', 'Cebu City', 10.330, 123.906),
    _cafe('2', 'IT Park', 'Cebu City', 10.332, 123.904),
    _cafe('3', 'Lahug', 'Cebu City', 10.333, 123.896),
    _cafe('4', 'Banilad', 'Mandaue City', 10.345, 123.913),
    _cafe('5', null, null, 10.0, 123.0),
  ]);

  test('groups neighbourhoods and averages their position', () {
    final itPark = index.match('IT Park').first;
    expect(itPark.label, 'IT Park');
    expect(itPark.subtitle, 'Cebu City');
    expect(itPark.lat, closeTo(10.331, 1e-9));
    expect(itPark.lng, closeTo(123.905, 1e-9));
    expect(itPark.kind, SearchOriginKind.place);
  });

  test('cities are places of their own, without a subtitle', () {
    final city = index.match('Mandaue').firstWhere((p) => p.subtitle == null);
    expect(city.label, 'Mandaue City');
    expect(city.lat, closeTo(10.345, 1e-9));
  });

  test('match ranks starts-with before contains', () {
    final labels = index.match('la').map((p) => p.label).toList();
    expect(labels.first, 'Lahug');
    expect(labels, contains('Banilad'));
  });

  test('match is case-insensitive and also checks the city', () {
    final labels = index.match('cebu').map((p) => p.label).toSet();
    expect(labels, containsAll(['IT Park', 'Lahug', 'Cebu City']));
  });

  test('empty text and no match give nothing', () {
    expect(index.match(''), isEmpty);
    expect(index.match('   '), isEmpty);
    expect(index.match('Manila'), isEmpty);
  });

  test('match respects the limit', () {
    expect(index.match('c', limit: 2), hasLength(2));
  });

  test('nearest finds the closest neighbourhood within range', () {
    expect(index.nearest(10.3335, 123.8962)?.label, 'Lahug');
    expect(index.nearest(10.0, 123.0), isNull);
  });

  test('empty index matches nothing', () {
    expect(SearchPlaceIndex.empty.match('IT'), isEmpty);
    expect(SearchPlaceIndex.empty.nearest(10.33, 123.9), isNull);
  });

  test('distanceMeters is roughly right', () {
    // One degree of latitude is about 111 km.
    expect(
      SearchPlaceIndex.distanceMeters(10, 123, 11, 123),
      closeTo(111195, 500),
    );
  });
}
