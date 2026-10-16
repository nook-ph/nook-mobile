import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/saver_survey/data/save_dates_source.dart';

void main() {
  group('AccountSaveDatesSource.parseRows', () {
    const types = {'w': 'want_to_try', 'b': 'been'};

    test('keeps Want to Try rows with their cafe, Been rows as dates', () {
      final saves = AccountSaveDatesSource.parseRows([
        {
          'list_id': 'w',
          'added_at': '2026-09-01T02:00:00Z',
          'cafe': {
            'id': 'c1',
            'name': 'Kapehan',
            'featured_image_url': 'https://x/y.jpg',
            'lat': 14.5,
            'lng': 121.0,
            'operating_hours': null,
          },
        },
        {'list_id': 'b', 'added_at': '2026-09-02T02:00:00Z', 'cafe': null},
      ], types);

      expect(saves.wantToTry, hasLength(1));
      expect(saves.wantToTry.single.cafe?.name, 'Kapehan');
      expect(saves.wantToTry.single.cafe?.coverImage, 'https://x/y.jpg');
      expect(saves.been, [DateTime.parse('2026-09-02T02:00:00Z')]);
    });

    test('drops a Want to Try whose cafe did not come back', () {
      final saves = AccountSaveDatesSource.parseRows([
        {'list_id': 'w', 'added_at': '2026-08-01T02:00:00Z', 'cafe': null},
        {
          'list_id': 'w',
          'added_at': 'not a date',
          'cafe': {'id': 'c', 'name': 'n'},
        },
        {'list_id': 'other', 'added_at': '2026-08-01T02:00:00Z'},
      ], types);

      expect(saves.wantToTry, isEmpty);
      expect(saves.been, isEmpty);
    });
  });
}
