import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/search/data/search_recents_store.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SearchRecentsStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = SearchRecentsStore();
  });

  group('searches', () {
    test('starts empty', () async {
      expect(await store.searches(), isEmpty);
    });

    test('newest first, trimmed, blank ignored', () async {
      await store.addSearch('matcha');
      await store.addSearch('  latte ');
      await store.addSearch('   ');
      expect(await store.searches(), ['latte', 'matcha']);
    });

    test('a repeat moves up instead of duplicating, ignoring case', () async {
      await store.addSearch('matcha');
      await store.addSearch('latte');
      await store.addSearch('Matcha');
      expect(await store.searches(), ['Matcha', 'latte']);
    });

    test('keeps at most maxItems', () async {
      for (var i = 0; i < SearchRecentsStore.maxItems + 3; i++) {
        await store.addSearch('q$i');
      }
      final list = await store.searches();
      expect(list, hasLength(SearchRecentsStore.maxItems));
      expect(list.first, 'q${SearchRecentsStore.maxItems + 2}');
    });

    test('clear all empties the list and hands back what was there', () async {
      await store.addSearch('matcha');
      await store.addSearch('latte');
      expect(await store.clearSearches(), ['latte', 'matcha']);
      expect(await store.searches(), isEmpty);
      // Clearing an empty list is harmless.
      expect(await store.clearSearches(), isEmpty);
    });

    test('undo restores the cleared list in its order', () async {
      await store.addSearch('matcha');
      await store.addSearch('latte');
      final cleared = await store.clearSearches();
      expect(await store.restoreSearches(cleared), ['latte', 'matcha']);
      expect(await SearchRecentsStore().searches(), ['latte', 'matcha']);
    });

    test(
      'undo keeps a search made after the clear, without duplicates',
      () async {
        await store.addSearch('matcha');
        await store.addSearch('latte');
        final cleared = await store.clearSearches();
        await store.addSearch('Latte');
        await store.addSearch('mocha');
        expect(await store.restoreSearches(cleared), [
          'mocha',
          'Latte',
          'matcha',
        ]);
      },
    );

    test('clearing searches leaves recent places alone', () async {
      const lahug = SearchOrigin(label: 'Lahug', lat: 10.33, lng: 123.89);
      await store.addPlace(lahug);
      await store.addSearch('matcha');
      await store.clearSearches();
      expect(await store.places(), [lahug]);
    });

    test('remove drops one entry', () async {
      await store.addSearch('matcha');
      await store.addSearch('latte');
      expect(await store.removeSearch('matcha'), ['latte']);
      expect(await store.searches(), ['latte']);
    });
  });

  group('places', () {
    const itPark = SearchOrigin(
      label: 'IT Park',
      subtitle: 'Cebu City',
      lat: 10.33,
      lng: 123.90,
    );
    const lahug = SearchOrigin(
      label: 'Lahug',
      subtitle: 'Cebu City',
      lat: 10.33,
      lng: 123.89,
    );

    test('round-trips through preferences, newest first', () async {
      await store.addPlace(itPark);
      await store.addPlace(lahug);
      expect(await SearchRecentsStore().places(), [lahug, itPark]);
    });

    test('a repeat place moves up', () async {
      await store.addPlace(itPark);
      await store.addPlace(lahug);
      await store.addPlace(itPark);
      expect(await store.places(), [itPark, lahug]);
    });

    test('pins are not remembered', () async {
      await store.addPlace(const SearchOrigin.pin(lat: 10.3, lng: 123.9));
      expect(await store.places(), isEmpty);
    });

    test('each account has its own recents (S-7)', () async {
      String? user;
      final perUser = SearchRecentsStore(userId: () => user);

      await perUser.addSearch('guest latte');
      await perUser.addPlace(itPark);

      user = 'user-a';
      expect(await perUser.searches(), isEmpty);
      expect(await perUser.places(), isEmpty);
      await perUser.addSearch('matcha');
      await perUser.addPlace(lahug);

      user = 'user-b';
      expect(await perUser.searches(), isEmpty);
      expect(await perUser.places(), isEmpty);

      user = 'user-a';
      expect(await perUser.searches(), ['matcha']);
      expect(await perUser.places(), [lahug]);

      user = null;
      expect(await perUser.searches(), ['guest latte']);
      expect(await perUser.places(), [itPark]);
    });

    test('corrupt stored data reads as empty', () async {
      SharedPreferences.setMockInitialValues({
        'search.recentPlaces': ['not json', '{"label":1}'],
      });
      expect(await SearchRecentsStore().places(), isEmpty);
    });
  });
}
