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

    test('none visited yet: only what is left, never "0 of"', () {
      const p = PlacesProgress(been: 0, wantToTry: 5);
      expect(p.label, '5 to try');
      expect(p.semanticsLabel, '5 cafes to try');
      expect(p.fraction, 0);
      expect(p.isComplete, isFalse);
    });

    test('some visited', () {
      const p = PlacesProgress(been: 3, wantToTry: 5);
      expect(p.total, 8);
      expect(p.label, '3 been · 5 to try');
      expect(p.semanticsLabel, '3 cafes been, 5 to try');
      expect(p.fraction, closeTo(0.375, 1e-9));
    });

    test('all visited', () {
      const p = PlacesProgress(been: 8, wantToTry: 0);
      expect(p.isComplete, isTrue);
      expect(p.label, 'All 8 been');
      expect(p.semanticsLabel, 'All 8 cafes been');
      expect(p.fraction, 1);
    });

    test('one cafe reads singular for screen readers', () {
      expect(
        const PlacesProgress(been: 0, wantToTry: 1).semanticsLabel,
        '1 cafe to try',
      );
      expect(
        const PlacesProgress(been: 1, wantToTry: 1).semanticsLabel,
        '1 cafe been, 1 to try',
      );
    });

    test('saving one more never reads as going backwards', () {
      const before = PlacesProgress(been: 1, wantToTry: 2);
      const after = PlacesProgress(been: 1, wantToTry: 3);
      expect(before.label, '1 been · 2 to try');
      expect(after.label, '1 been · 3 to try');
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
      expect(before.label, '2 to try');
      expect(after.label, '1 been · 1 to try');
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
