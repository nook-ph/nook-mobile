import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/public_profile/data/public_profile_repository_impl.dart';
import 'package:nook/features/public_profile/domain/entities/public_profile.dart';

Map<String, dynamic> _json({bool public = true}) => {
  'user_id': 'u1',
  'username': 'cris',
  'full_name': 'Cris',
  'avatar_url': null,
  'bio': null,
  'highlights_public': public,
  'is_self': false,
  'counts': {'reviews': 1, 'ranked': 5, 'cups': 2},
  'photos': [
    {
      'id': 'p1',
      'cafe_id': 'c1',
      'cafe_name': 'Cafe 1',
      'cafe_area': 'Lahug, Cebu City',
      'image_url': 'https://x/1.jpg',
      'drink_name': null,
      'taken_at': '2026-10-01T00:00:00Z',
      'pin_order': 1,
      'source': 'gallery',
      'source_id': null,
    },
  ],
  'reviews': [
    {
      'id': 'r1',
      'cafe_id': 'c1',
      'cafe_name': 'Cafe 1',
      'rating': 5,
      'content': 'Great',
      'image_urls': <String>[],
      'created_at': '2026-09-01T00:00:00Z',
    },
  ],
};

void main() {
  test('parses the RPC', () {
    final p = publicProfileFromJson(_json());
    expect(p.username, 'cris');
    expect(p.rankedCount, 5);
    expect(p.cupCount, 2);
    expect(p.photos.single.cafeName, 'Cafe 1');
    expect(p.reviews.single.cafeName, 'Cafe 1');
  });

  test('switch off: no photos or private counts, whatever arrives', () {
    final p = publicProfileFromJson(_json(public: false));
    expect(p.highlightsPublic, isFalse);
    expect(p.photos, isEmpty);
    expect(p.rankedCount, isNull);
    expect(p.cupCount, isNull);
    expect(p.reviews, hasLength(1));
  });

  test('the counts line leaves out what is hidden or zero', () {
    expect(
      publicCountsLine(reviews: 4, ranked: 18, cups: 11),
      '18 cafes ranked · 4 reviews · 11 cups',
    );
    expect(publicCountsLine(reviews: 1), '1 review');
    expect(
      publicCountsLine(reviews: 0, ranked: 1, cups: 0),
      '1 cafe ranked · 0 reviews',
    );
  });
}
