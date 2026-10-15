import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';

void main() {
  const cafe = CafeSnapshot(
    id: 'c1',
    name: 'Kape Uno',
    address: 'Lahug',
    neighborhood: 'Lahug',
    city: 'Cebu City',
    coverImage: 'https://example.com/a.jpg',
    rating: 4.5,
    reviewCount: 12,
    tags: ['Specialty'],
    lat: 10.3,
    lng: 123.9,
    operatingHours: {
      'monday': {'open': '08:00', 'close': '20:00'},
    },
  );

  test('a save survives a round trip through JSON', () {
    final save = GuestSave(
      cafe: cafe,
      status: CafeStatus.wantToTry,
      savedAt: DateTime.utc(2026, 10, 1, 8),
    );

    expect(GuestSave.fromJson(save.toJson()), save);
  });

  test('a recently viewed cafe survives a round trip through JSON', () {
    final entry = RecentlyViewedCafe(
      cafe: cafe,
      viewedAt: DateTime.utc(2026, 10, 2),
    );

    expect(RecentlyViewedCafe.fromJson(entry.toJson()), entry);
  });

  test('a snapshot with only an id and name reads back with defaults', () {
    const bare = CafeSnapshot(id: 'c2', name: 'Bare');

    final back = CafeSnapshot.fromJson(bare.toJson());

    expect(back, bare);
    expect(back!.toSummary().operatingHours, isNull);
  });

  test('corrupt entries read as null rather than throwing', () {
    expect(CafeSnapshot.fromJson('nope'), isNull);
    expect(CafeSnapshot.fromJson({'name': 'No id'}), isNull);
    expect(
      GuestSave.fromJson({
        'cafe': cafe.toJson(),
        'status': 'none',
        'saved_at': '2026-10-01T00:00:00Z',
      }),
      isNull,
    );
    expect(
      GuestSave.fromJson({
        'cafe': cafe.toJson(),
        'status': 'been',
        'saved_at': 'not a date',
      }),
      isNull,
    );
  });
}
