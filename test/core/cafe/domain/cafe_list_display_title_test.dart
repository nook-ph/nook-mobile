import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/cafe_list_display_title.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';

CafeList _cafeList({
  required String id,
  required String name,
  bool isDefault = false,
}) {
  return CafeList(
    id: id,
    name: name,
    description: null,
    coverImageUrl: null,
    isDefault: isDefault,
    isPublic: false,
    cafeCount: 0,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

void main() {
  group('cafeListDisplayTitle', () {
    test('default list with empty name uses Favorites', () {
      expect(
        cafeListDisplayTitle(_cafeList(id: 'x', name: '   ', isDefault: true)),
        'Favorites',
      );
    });

    test('default list with trimmed name uses that name', () {
      expect(
        cafeListDisplayTitle(
          _cafeList(id: 'x', name: 'My picks', isDefault: true),
        ),
        'My picks',
      );
    });

    test('non-default list uses raw name', () {
      expect(
        cafeListDisplayTitle(_cafeList(id: 'l1', name: 'Weekend')),
        'Weekend',
      );
    });
  });
}
