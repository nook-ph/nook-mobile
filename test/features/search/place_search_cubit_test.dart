import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/search/domain/entities/place_suggestion.dart';
import 'package:nook/features/search/domain/search_place_index.dart';
import 'package:nook/features/search/presentation/cubit/place_search_cubit.dart';

import 'place_search_fakes.dart';

CafeSummary _cafe(String id, String hood, double lat, double lng) =>
    CafeSummary(
      id: id,
      name: 'Cafe $id',
      neighborhood: hood,
      city: 'Cebu City',
      rating: 4,
      lat: lat,
      lng: lng,
    );

void main() {
  final index = SearchPlaceIndex.fromCafes([
    _cafe('1', 'IT Park', 10.330, 123.906),
    _cafe('2', 'Lahug', 10.332, 123.898),
  ]);
  const debounce = Duration(milliseconds: 40);

  PlaceSearchCubit cubit(FakePlaceSearchRepository repo) => PlaceSearchCubit(
    repository: repo,
    places: Future.value(index),
    debounce: debounce,
  );

  Future<void> settle() => Future<void>.delayed(debounce * 3);

  test('asks the map once typing pauses, with the last query only', () async {
    final repo = FakePlaceSearchRepository(
      answers: {
        'sm seaside': [landmark('SM Seaside City Cebu')],
      },
    );
    final c = cubit(repo);
    await Future<void>.delayed(Duration.zero);
    for (final q in ['sm ', 'sm s', 'sm se', 'sm seaside']) {
      c.queryChanged(q);
    }
    expect(c.state.status, PlaceSearchStatus.loading);
    await settle();
    expect(repo.queries, ['sm seaside']);
    expect(c.state.status, PlaceSearchStatus.done);
    expect(c.state.results.single.origin.label, 'SM Seaside City Cebu');
    expect(c.state.showsAttribution, isTrue);
    await c.close();
  });

  test(
    'under 3 characters only Nook areas match; the map is not asked',
    () async {
      final repo = FakePlaceSearchRepository();
      final c = cubit(repo);
      await Future<void>.delayed(Duration.zero);
      c.queryChanged('la');
      await settle();
      expect(repo.queries, isEmpty);
      expect(c.state.status, PlaceSearchStatus.idle);
      expect(c.state.results.single.origin.label, 'Lahug');
      expect(c.state.results.single.type, PlaceType.nookArea);
      expect(c.state.showsAttribution, isFalse);
      await c.close();
    },
  );

  test('a slow answer to an older query is dropped', () async {
    final repo = FakePlaceSearchRepository(
      answers: {
        'ayala': [landmark('Ayala Center Cebu')],
        'ayala center': [landmark('Ayala Center Cebu, Cebu Business Park')],
      },
    );
    final slow = repo.hold['ayala'] = Completer<void>();
    final c = cubit(repo);
    c.queryChanged('ayala');
    await settle(); // "ayala" is now in flight, held.
    c.queryChanged('ayala center');
    await settle();
    expect(
      c.state.results.single.origin.label,
      'Ayala Center Cebu, Cebu Business Park',
    );
    slow.complete();
    await settle();
    // The late "ayala" reply did not overwrite the newer results.
    expect(
      c.state.results.single.origin.label,
      'Ayala Center Cebu, Cebu Business Park',
    );
    await c.close();
  });

  test(
    'Nook areas come first; the same name from the map is not repeated',
    () async {
      final repo = FakePlaceSearchRepository(
        answers: {
          'lahug': [
            landmark('Lahug'),
            landmark('Lahug Elementary School', subtitle: 'Lahug, Cebu City'),
          ],
        },
      );
      final c = cubit(repo);
      await Future<void>.delayed(Duration.zero);
      c.queryChanged('lahug');
      await settle();
      expect(c.state.results.map((p) => p.origin.label), [
        'Lahug',
        'Lahug Elementary School',
      ]);
      expect(c.state.results.first.type, PlaceType.nookArea);
      await c.close();
    },
  );

  test('when the map is unavailable, Nook areas still show', () async {
    final repo = FakePlaceSearchRepository(fail: true);
    final c = cubit(repo);
    await Future<void>.delayed(Duration.zero);
    c.queryChanged('it park');
    await settle();
    expect(c.state.status, PlaceSearchStatus.unavailable);
    expect(c.state.results.single.origin.label, 'IT Park');
    expect(c.state.showsAttribution, isFalse);
    await c.close();
  });

  test('closing mid-request does not throw', () async {
    final repo = FakePlaceSearchRepository();
    final wait = repo.hold['mango'] = Completer<void>();
    final c = cubit(repo);
    c.queryChanged('mango');
    await settle();
    await c.close();
    wait.complete();
    await settle();
  });
}
