import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/home_page/data/home_layout_repository.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';
import 'package:nook/features/home_page/domain/use_cases/get_cafe_summaries_usecase.dart';
import 'package:nook/features/home_page/domain/use_cases/get_layout_shelves_usecase.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, Object?> _response(String version, {List<Object?>? sections}) => {
  'version': version,
  'published_at': '2026-10-16T00:00:00+08:00',
  'document': {
    'schema': 1,
    'sections':
        sections ??
        [
          {'id': 'newest', 'type': 'builtin'},
        ],
  },
};

CafeSummary _cafe(String id) =>
    CafeSummary(id: id, name: 'Cafe $id', rating: 4.5);

class _Repo implements ICafeRepository {
  final queries = <CafeQuery>[];
  List<CafeSummary> answer = const [];

  @override
  Future<List<CafeSummary>> getCafes(CafeQuery query) async {
    queries.add(query);
    return answer;
  }

  @override
  Future<void> warmCache(List<CafeSummary> summaries) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Feed extends GetHomeFeedUseCase {
  _Feed() : super(_Repo());

  @override
  Stream<HomeFeedUpdate> watch({int page = 0, int limit = 20}) async* {
    yield (
      data: (
        feed: (
          nearby: <CafeSummary>[],
          topRated: [_cafe('t1'), _cafe('t2'), _cafe('t3')],
          trending: <CafeSummary>[],
          newest: [_cafe('n1')],
          specialtyNearby: <CafeSummary>[],
          laptopFriendly: <CafeSummary>[],
          localBeans: <CafeSummary>[],
        ),
        locationDenied: false,
        locationServicesOff: false,
      ),
      nearbyPending: false,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  HomeLayoutRepository repo(Future<Object?> Function() fetch) =>
      HomeLayoutRepository(fetch: fetch, cache: HomeLayoutCache());

  group('HomeLayoutRepository', () {
    test('no cache and offline: the built-in Home', () async {
      final r = repo(() async => throw Exception('offline'));
      expect(await r.cached(), isNull);
      final out = await r.refresh();
      expect(out.ok, isFalse);
      expect(out.layout, isNull);
      expect(out.changed, isFalse);
    });

    test('a good answer is cached and served first next time', () async {
      final first = await repo(() async => _response('v1')).refresh();
      expect(first.ok, isTrue);
      expect(first.changed, isTrue);
      expect(first.layout!.version, 'v1');

      // Next launch, offline: the cached layout stays.
      final next = repo(() async => throw Exception('offline'));
      expect((await next.cached())!.version, 'v1');
      final refreshed = await next.refresh();
      expect(refreshed.ok, isFalse);
      expect(refreshed.layout!.version, 'v1');
    });

    test('the same answer again is not a change', () async {
      await repo(() async => _response('v1')).refresh();
      final again = repo(() async => _response('v1'));
      await again.cached();
      expect((await again.refresh()).changed, isFalse);
    });

    test('nothing published clears the cache: built-in Home', () async {
      await repo(() async => _response('v1')).refresh();
      final none = repo(() async => null);
      expect((await none.cached())!.version, 'v1');
      final out = await none.refresh();
      expect(out.layout, isNull);
      expect(out.changed, isTrue);
      expect(await repo(() async => null).cached(), isNull);
    });

    test(
      'a schema this app does not know falls back and clears the cache',
      () async {
        await repo(() async => _response('v1')).refresh();
        final out = await repo(
          () async => {
            'version': 'v2',
            'document': {'schema': 2},
          },
        ).refresh();
        expect(out.ok, isTrue);
        expect(out.layout, isNull);
        expect(await repo(() async => null).cached(), isNull);
      },
    );

    test('a corrupt cache is ignored', () async {
      SharedPreferences.setMockInitialValues({'homeLayoutCache': '{nope'});
      expect(await repo(() async => null).cached(), isNull);
    });
  });

  group('GetLayoutShelvesUseCase', () {
    test(
      'picked ids in order via cafesByIds, rules via get_cafes tag',
      () async {
        final cafes = _Repo()..answer = [_cafe('r1'), _cafe('r2'), _cafe('r3')];
        List<String>? asked;
        final shelves =
            await GetLayoutShelvesUseCase(
              repository: cafes,
              cafesByIds: (ids) async {
                asked = ids;
                return [_cafe('b'), _cafe('a')]; // any order, one missing
              },
              position: () async => null,
            )(
              HomeLayout.fromRpc(
                _response(
                  'v1',
                  sections: [
                    {
                      'id': 'featured',
                      'type': 'builtin',
                      'cafe_ids': ['a', 'gone', 'b'],
                    },
                    {
                      'id': 'custom:p',
                      'type': 'custom',
                      'title': 'P',
                      'source': 'picked',
                      'cafe_ids': ['b', 'a'],
                    },
                    {
                      'id': 'custom:r',
                      'type': 'custom',
                      'title': 'R',
                      'source': 'rule',
                      'rule': {
                        'tag': 'Open Late',
                        'sort': 'nearby',
                        'limit': 5,
                      },
                    },
                  ],
                ),
              ),
            );
        expect(asked, ['a', 'gone', 'b']);
        expect([for (final c in shelves['featured']!) c.id], ['a', 'b']);
        expect([for (final c in shelves['custom:p']!) c.id], ['b', 'a']);
        expect(shelves['custom:r'], hasLength(3));
        final q = cafes.queries.single;
        expect(q.tags, ['Open Late']);
        // No position: nearby falls back to top rated.
        expect(q.sort, 'top_rated');
        expect(q.limit, 5);
      },
    );

    test('ids are sent at most 100 per call', () async {
      final calls = <int>[];
      final layout = HomeLayout.fromRpc(
        _response(
          'v1',
          sections: [
            for (var s = 0; s < 5; s++)
              {
                'id': 'custom:$s',
                'type': 'custom',
                'title': 'S$s',
                'source': 'picked',
                'cafe_ids': [for (var i = 0; i < 30; i++) 'c$s-$i'],
              },
          ],
        ),
      );
      final shelves = await GetLayoutShelvesUseCase(
        repository: _Repo(),
        cafesByIds: (ids) async {
          calls.add(ids.length);
          return [for (final id in ids) _cafe(id)];
        },
      )(layout);
      expect(calls, [100, 50]);
      expect(shelves['custom:4'], hasLength(30));
    });

    test('a failed id fetch leaves the sections out', () async {
      final shelves =
          await GetLayoutShelvesUseCase(
            repository: _Repo(),
            cafesByIds: (_) async => throw Exception('no such function'),
          )(
            HomeLayout.fromRpc(
              _response(
                'v1',
                sections: [
                  {
                    'id': 'featured',
                    'type': 'builtin',
                    'cafe_ids': ['a'],
                  },
                ],
              ),
            ),
          );
      expect(shelves, isEmpty);
    });
  });

  group('HomeBloc with a layout', () {
    test('no layout repository: the state carries no layout', () async {
      final bloc = HomeBloc(getHomeFeedUseCase: _Feed());
      bloc.add(LoadHomeDataEvent());
      final loaded =
          await bloc.stream.firstWhere((s) => s is HomeLoadedState)
              as HomeLoadedState;
      expect(loaded.layout, isNull);
      expect(loaded.layoutShelves, isEmpty);
      await bloc.close();
    });

    test('fetch fails with no cache: built-in Home, one emission', () async {
      final bloc = HomeBloc(
        getHomeFeedUseCase: _Feed(),
        layoutRepository: repo(() async => throw Exception('missing rpc')),
        getLayoutShelves: GetLayoutShelvesUseCase(
          repository: _Repo(),
          cafesByIds: (_) async => const [],
        ),
      );
      final states = <HomeState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(LoadHomeDataEvent());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final loaded = states.whereType<HomeLoadedState>().toList();
      expect(loaded, hasLength(1));
      expect(loaded.single.layout, isNull);
      await sub.cancel();
      await bloc.close();
    });

    test('cache drawn first, the server\'s new layout follows', () async {
      await repo(() async => _response('v1')).refresh();
      final bloc = HomeBloc(
        getHomeFeedUseCase: _Feed(),
        layoutRepository: repo(() async => _response('v2')),
        getLayoutShelves: GetLayoutShelvesUseCase(
          repository: _Repo(),
          cafesByIds: (_) async => const [],
        ),
      );
      final states = <HomeState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(LoadHomeDataEvent());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final versions = [
        for (final s in states.whereType<HomeLoadedState>()) s.layout?.version,
      ];
      expect(versions, ['v1', 'v2']);
      await sub.cancel();
      await bloc.close();
    });

    test('the server layout does not undo a state emitted while its '
        'shelves load', () async {
      await repo(() async => _response('v1')).refresh();
      final shelvesGate = Completer<void>();
      final bloc = HomeBloc(
        getHomeFeedUseCase: _Feed(),
        layoutRepository: repo(
          () async => _response(
            'v2',
            sections: [
              {
                'id': 'custom:p',
                'type': 'custom',
                'title': 'Picked',
                'source': 'picked',
                'cafe_ids': ['9a2b3c4d-0000-4000-8000-00000000000a'],
              },
            ],
          ),
        ),
        getLayoutShelves: GetLayoutShelvesUseCase(
          repository: _Repo(),
          cafesByIds: (_) async {
            await shelvesGate.future;
            return const [];
          },
        ),
      );
      final states = <HomeState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(LoadHomeDataEvent());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.add(HomeDismissLocationBannerEvent());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      shelvesGate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final last = states.whereType<HomeLoadedState>().last;
      expect(last.layout?.version, 'v2');
      expect(last.locationBannerDismissed, isTrue);
      await sub.cancel();
      await bloc.close();
    });

    test('a refresh whose shelf cafes fail keeps the ones on screen', () async {
      final response = _response(
        'v1',
        sections: [
          {
            'id': 'custom:p',
            'type': 'custom',
            'title': 'Picked',
            'source': 'picked',
            'cafe_ids': ['9a2b3c4d-0000-4000-8000-00000000000a'],
          },
        ],
      );
      var fail = false;
      final bloc = HomeBloc(
        getHomeFeedUseCase: _Feed(),
        layoutRepository: repo(() async => response),
        getLayoutShelves: GetLayoutShelvesUseCase(
          repository: _Repo(),
          cafesByIds: (_) async {
            if (fail) throw Exception('timeout');
            return [_cafe('9a2b3c4d-0000-4000-8000-00000000000a')];
          },
        ),
      );
      final states = <HomeState>[];
      final sub = bloc.stream.listen(states.add);
      bloc.add(LoadHomeDataEvent());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        states.whereType<HomeLoadedState>().last.layoutShelves['custom:p'],
        hasLength(1),
      );
      fail = true;
      bloc.add(LoadHomeDataEvent(refresh: true));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final last = states.whereType<HomeLoadedState>().last;
      expect(last.layout?.version, 'v1');
      expect(last.layoutShelves['custom:p'], hasLength(1));
      await sub.cancel();
      await bloc.close();
    });

    test('debug fixture is used instead of the server', () async {
      var fetched = false;
      final bloc = HomeBloc(
        getHomeFeedUseCase: _Feed(),
        layoutRepository: repo(() async {
          fetched = true;
          return null;
        }),
        debugLayoutFixture: (feed) => HomeLayout.fromRpc(_response('fixture'))!,
      );
      bloc.add(LoadHomeDataEvent());
      final loaded =
          await bloc.stream.firstWhere((s) => s is HomeLoadedState)
              as HomeLoadedState;
      expect(loaded.layout!.version, 'fixture');
      expect(fetched, isFalse);
      await bloc.close();
    });
  });
}
