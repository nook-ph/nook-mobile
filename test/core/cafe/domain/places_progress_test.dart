import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/places_progress.dart';

CafeList _list(String type, int count) => CafeList(
  id: type,
  name: type,
  isDefault: false,
  isPublic: false,
  cafeCount: count,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  listType: type,
);

void main() {
  group('PlacesProgress', () {
    test('nothing saved: empty, no label', () {
      const p = PlacesProgress(been: 0, wantToTry: 0);
      expect(p.isEmpty, isTrue);
      expect(p.label, isNull);
      expect(p.semanticsLabel, isNull);
      expect(p.fraction, 0);
    });

    test('none visited yet', () {
      const p = PlacesProgress(been: 0, wantToTry: 5);
      expect(p.label, 'Been to 0 of 5');
      expect(p.fraction, 0);
      expect(p.isComplete, isFalse);
    });

    test('some visited', () {
      const p = PlacesProgress(been: 3, wantToTry: 5);
      expect(p.total, 8);
      expect(p.label, 'Been to 3 of 8');
      expect(p.semanticsLabel, 'Been to 3 of your 8 places');
      expect(p.fraction, closeTo(0.375, 1e-9));
    });

    test('all visited', () {
      const p = PlacesProgress(been: 8, wantToTry: 0);
      expect(p.isComplete, isTrue);
      expect(p.label, 'Been to all 8');
      expect(p.fraction, 1);
    });

    test('one place reads singular for screen readers', () {
      expect(
        const PlacesProgress(been: 0, wantToTry: 1).semanticsLabel,
        'Been to 0 of your 1 place',
      );
    });

    test('fromStatuses counts Been and Want to Try, ignores none', () {
      final p = PlacesProgress.fromStatuses([
        CafeStatus.wantToTry,
        CafeStatus.been,
        CafeStatus.wantToTry,
        CafeStatus.none,
      ]);
      expect(p, const PlacesProgress(been: 1, wantToTry: 2));
    });

    test('a Want to Try marked Been moves from one count to the other', () {
      final before = PlacesProgress.fromStatuses([
        CafeStatus.wantToTry,
        CafeStatus.wantToTry,
      ]);
      final after = PlacesProgress.fromStatuses([
        CafeStatus.been,
        CafeStatus.wantToTry,
      ]);
      expect(before.label, 'Been to 0 of 2');
      expect(after.label, 'Been to 1 of 2');
    });

    test('fromLists reads the system lists only', () {
      final p = PlacesProgress.fromLists([
        _list('custom', 12),
        _list('been', 3),
        _list('want_to_try', 5),
      ]);
      expect(p, const PlacesProgress(been: 3, wantToTry: 5));
    });

    test('fromLists with no system lists is empty', () {
      expect(PlacesProgress.fromLists([_list('custom', 4)]).isEmpty, isTrue);
    });
  });
}
