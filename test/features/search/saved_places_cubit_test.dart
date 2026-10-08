import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/search/data/local_saved_places_repository.dart';
import 'package:nook/features/search/domain/entities/saved_place.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/repositories/i_saved_places_repository.dart';
import 'package:nook/features/search/presentation/cubit/saved_places_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'place_search_fakes.dart';

const _home = SavedPlace(
  kind: SavedPlaceKind.home,
  label: 'Home',
  address: 'Lahug, Cebu City',
  lat: 10.33,
  lng: 123.9,
);

void main() {
  test('load, add, rename, delete', () async {
    final repo = FakeSavedPlacesRepository();
    final c = SavedPlacesCubit(repo);
    await c.load();
    expect(c.state.status, SavedPlacesStatus.ready);
    expect(c.state.home, isNull);

    final home = await c.save(_home);
    expect(c.state.home, home);
    final lola = await c.save(
      const SavedPlace(
        kind: SavedPlaceKind.custom,
        label: 'Lola’s house',
        lat: 10.3,
        lng: 123.89,
      ),
    );
    expect(c.state.custom.single.label, 'Lola’s house');

    await c.save(lola.copyWith(label: 'Lola Nena’s house'));
    expect(c.state.custom.single.label, 'Lola Nena’s house');
    expect(repo.places, hasLength(2));

    await c.delete(lola);
    expect(c.state.custom, isEmpty);
    expect(repo.places, [home]);
    await c.close();
  });

  test('an edit is remembered as before and after', () async {
    final repo = FakeSavedPlacesRepository(places: [_home.copyWith(id: 'h')]);
    final c = SavedPlacesCubit(repo);
    await c.load();
    final moved = _home.copyWith(id: 'h', address: 'IT Park', lat: 10.329);
    await c.save(moved);
    expect(c.edits.single.$1.address, 'Lahug, Cebu City');
    expect(c.edits.single.$2, moved);
    await c.close();
  });

  test('a second Home replaces the first', () async {
    final repo = FakeSavedPlacesRepository();
    final c = SavedPlacesCubit(repo);
    await c.load();
    final first = await c.save(_home);
    final second = await c.save(
      _home.copyWith(address: 'Banilad, Cebu City', lat: 10.34),
    );
    expect(second.id, first.id);
    expect(repo.places.single.address, 'Banilad, Cebu City');
    await c.close();
  });

  test('a saved place is its own search origin, and ticks as current', () {
    final home = _home.copyWith(id: 'h');
    final origin = home.toOrigin();
    expect(origin.kind, SearchOriginKind.saved);
    expect(origin.fullLabel, 'Home');
    expect(origin, home.toOrigin());
    expect(SearchOrigin.fromJson(origin.toJson()), origin);
  });

  test('past the cap, saving says so', () async {
    final repo = FakeSavedPlacesRepository(
      places: [
        for (var i = 0; i < ISavedPlacesRepository.maxPlaces; i++)
          SavedPlace(
            id: '$i',
            kind: SavedPlaceKind.custom,
            label: 'Place $i',
            lat: 10,
            lng: 123,
          ),
      ],
    );
    final c = SavedPlacesCubit(repo);
    await c.load();
    expect(c.state.atLimit, isTrue);
    await expectLater(
      c.save(
        const SavedPlace(
          kind: SavedPlaceKind.custom,
          label: 'One more',
          lat: 10,
          lng: 123,
        ),
      ),
      throwsA(isA<SavedPlacesLimitReached>()),
    );
    await c.close();
  });

  test('a guest has no saved places and cannot save', () async {
    final c = SavedPlacesCubit(FakeSavedPlacesRepository(canSave: false));
    await c.load();
    expect(c.state.canSave, isFalse);
    expect(c.state.places, isEmpty);
    await c.close();
  });

  test('debug local store round-trips and keeps the cap', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalSavedPlacesRepository();
    final stored = await repo.save(_home);
    expect(stored.id, isNotNull);
    expect(await repo.list(), [stored]);
    await repo.save(stored.copyWith(address: 'IT Park'));
    expect((await repo.list()).single.address, 'IT Park');
    await repo.delete(stored.id!);
    expect(await repo.list(), isEmpty);
  });
}
