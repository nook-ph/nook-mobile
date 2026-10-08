import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/geo.dart';
import 'package:nook/features/map/presentation/widgets/bottom_modal_sheet.dart';

void main() {
  test('Nearby lists cafes by distance from the origin (UX S7)', () {
    const here = GeoPoint(lat: 10.33, lng: 123.90);
    // Roughly 1.7, 1.2, 3.7 and 1.5 km away, in the fetch's order.
    const cafes = [
      CafeSummary(id: 'a', name: 'A', rating: 4, lat: 10.345, lng: 123.90),
      CafeSummary(id: 'b', name: 'B', rating: 4, lat: 10.341, lng: 123.90),
      CafeSummary(id: 'c', name: 'C', rating: 4, lat: 10.363, lng: 123.90),
      CafeSummary(id: 'no-pin', name: 'No pin', rating: 4),
      CafeSummary(id: 'd', name: 'D', rating: 4, lat: 10.3435, lng: 123.90),
    ];
    expect(sortByDistance(cafes, here).map((c) => c.id), [
      'b',
      'd',
      'a',
      'c',
      'no-pin',
    ]);
  });
}
