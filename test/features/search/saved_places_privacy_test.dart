import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Saved places are private: only the search feature may read them, so a
/// profile (which is about to become public) can never carry them.
void main() {
  test('nothing outside search reads saved places', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (path.startsWith('lib/features/search/') ||
          path == 'lib/injection_container.dart' ||
          path == 'lib/features/map/presentation/pages/map_page.dart') {
        continue;
      }
      final source = entity.readAsStringSync();
      if (source.contains('saved_places') ||
          source.contains('SavedPlace') ||
          source.contains('ISavedPlacesRepository')) {
        offenders.add(path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('profile code never selects from saved_places', () {
    final profile = Directory('lib/features/profile');
    if (!profile.existsSync()) return;
    for (final entity in profile.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        expect(
          entity.readAsStringSync().contains('saved_places'),
          isFalse,
          reason: entity.path,
        );
      }
    }
  });

  test('the Supabase repository always filters by the signed-in user', () {
    final source = File(
      'lib/features/search/data/supabase_saved_places_repository.dart',
    ).readAsStringSync();
    // list, update and delete each scope to the owner on top of RLS.
    expect(RegExp(r"\.eq\('user_id', uid\)").allMatches(source).length, 3);
  });
}
