import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/cafe_data_revision.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/features/search/bloc/search_bloc.dart';
import 'package:nook/features/search/data/search_location.dart';
import 'package:nook/features/search/data/search_origin_store.dart';
import 'package:nook/features/search/domain/entities/search_origin.dart';
import 'package:nook/features/search/domain/use_cases/search_cafes_usecase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _cafe = CafeSummary(id: 'a', name: 'A', rating: 4);
const _itPark = SearchOrigin(
  label: 'IT Park',
  subtitle: 'Cebu City',
  lat: 10.33,
  lng: 123.9,
);

const SearchLocation _here = (
  lat: 10.3,
  lng: 123.9,
  status: SearchLocationStatus.available,
);
const SearchLocation _off = (
  lat: null,
  lng: null,
  status: SearchLocationStatus.off,
);
const SearchLocation _notAsked = (
  lat: null,
  lng: null,
  status: SearchLocationStatus.notAsked,
);

class _FakeSearch extends SearchCafesUseCase {
  _FakeSearch() : super(_StubRepository());

  final queries = <CafeQuery>[];
  List<CafeSummary> Function(CafeQuery query) answer = (_) => const [_cafe];

  /// Holds a request open until the returned future completes.
  Future<void> Function(CafeQuery query)? wait;

  @override
  Future<List<CafeSummary>> call(CafeQuery query) async {
    queries.add(query);
    await wait?.call(query);
    return answer(query);
  }
}

class _StubRepository implements ICafeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _FakeSearch search;
  late SearchLocation location;
  final supabase = SupabaseClient('http://localhost:54321', 'anon');

  SearchBloc build({SearchOriginStore? store}) {
    final bloc = SearchBloc(
      searchCafesUseCase: search,
      supabase: supabase,
      originStore: store,
      resolveLocation: () async => location,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  /// A tag change fetches without the query debounce.
  Future<SearchState> searchByTag(SearchBloc bloc) async {
    bloc.add(const SearchTagsChanged({'Free WiFi'}));
    return bloc.stream.firstWhere((s) => s.status == SearchStatus.success);
  }

  setUp(() {
    search = _FakeSearch();
    location = _here;
  });

  test('a posted or deleted review fetches the rows again (UX S6)', () async {
    final bloc = build();
    await searchByTag(bloc);
    expect(search.queries, hasLength(1));
    search.answer = (_) => const [CafeSummary(id: 'a', name: 'A', rating: 3)];
    CafeDataRevision.reviewsChanged();
    final next = await bloc.stream.firstWhere(
      (s) => s.status == SearchStatus.success,
    );
    expect(search.queries, hasLength(2));
    expect(next.cafes.single.rating, 3);
  });

  test('a review change before any search fetches nothing', () async {
    build();
    CafeDataRevision.reviewsChanged();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(search.queries, isEmpty);
  });

  group('location', () {
    test('with a position, nearest stays nearest', () async {
      final state = await searchByTag(build());
      expect(search.queries.single.sort, 'nearby');
      expect(search.queries.single.lat, 10.3);
      expect(state.hasPosition, isTrue);
      expect(state.sortFellBack, isFalse);
      expect(state.shownSort, 'nearby');
      expect(state.location, SearchLocationStatus.available);
      expect(state.locationUnavailable, isFalse);
    });

    test('location off: results come back by rating and say so', () async {
      location = _off;
      final state = await searchByTag(build());
      expect(search.queries.single.sort, 'top_rated');
      expect(search.queries.single.lat, isNull);
      expect(state.hasPosition, isFalse);
      expect(state.shownSort, 'top_rated');
      expect(state.location, SearchLocationStatus.off);
      expect(state.locationUnavailable, isTrue);
    });

    test('a plain denial is treated the same as a permanent one', () async {
      // The resolver reports a once-denied permission as off; the bloc has
      // no deniedForever special case left.
      location = _off;
      final state = await searchByTag(build());
      expect(state.locationUnavailable, isTrue);
      expect(state.locationDenied, isTrue);
    });

    test('a chosen place needs no phone location', () async {
      location = _off;
      final bloc = build();
      bloc.add(const SearchOriginChanged(_itPark));
      final state = await searchByTag(bloc);
      expect(search.queries.last.sort, 'nearby');
      expect(search.queries.last.lat, _itPark.lat);
      expect(state.hasPosition, isTrue);
      expect(state.locationUnavailable, isFalse);
    });

    test('checking location on the idle screen only sets the status', () async {
      location = _notAsked;
      final bloc = build();
      bloc.add(const SearchLocationChecked());
      final state = await bloc.stream.first;
      expect(state.location, SearchLocationStatus.notAsked);
      expect(state.status, SearchStatus.initial);
      expect(search.queries, isEmpty);
    });

    test('turning location on refetches results that had none', () async {
      location = _off;
      final bloc = build();
      await searchByTag(bloc);

      location = _here;
      bloc.add(const SearchLocationChecked());
      final state = await bloc.stream.firstWhere(
        (s) => s.status == SearchStatus.success && s.hasPosition,
      );
      expect(search.queries.last.sort, 'nearby');
      expect(state.shownSort, 'nearby');
      expect(state.location, SearchLocationStatus.available);
    });

    test('an unchanged status does nothing', () async {
      final bloc = build();
      await searchByTag(bloc);
      bloc.add(const SearchLocationChecked());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(search.queries, hasLength(1));
    });
  });

  group('paging', () {
    test('a late next page is not appended to newer results (S-4)', () async {
      search.answer = (_) => List.filled(20, _cafe);
      final bloc = build();
      await searchByTag(bloc);

      final nextPage = Completer<void>();
      search.wait = (q) => q.page == 1 ? nextPage.future : Future.value();
      bloc.add(const SearchLoadMore());
      await pumpEventQueue();
      expect(search.queries.last.page, 1);

      bloc.add(const SearchSortChanged('top_rated'));
      await bloc.stream.firstWhere(
        (s) => s.status == SearchStatus.success && s.sort == 'top_rated',
      );
      nextPage.complete();
      await pumpEventQueue();

      expect(bloc.state.cafes, hasLength(20));
      expect(bloc.state.page, 0);
      expect(bloc.state.sort, 'top_rated');
    });

    test('a failed next page keeps the results and waits for a retry '
        '(S-5)', () async {
      search.answer = (q) =>
          q.page == 0 ? List.filled(20, _cafe) : throw Exception('offline');
      final bloc = build();
      await searchByTag(bloc);

      bloc.add(const SearchLoadMore());
      final failed = await bloc.stream.firstWhere((s) => s.loadMoreFailed);
      expect(failed.status, SearchStatus.success);
      expect(failed.cafes, hasLength(20));
      expect(failed.lastError, isException);

      // The list asks again on every build near its end; a failing page is
      // not hammered.
      bloc.add(const SearchLoadMore());
      await pumpEventQueue();
      expect(search.queries.where((q) => q.page == 1), hasLength(1));

      search.answer = (q) => List.filled(q.page == 0 ? 20 : 5, _cafe);
      bloc.add(const SearchLoadMore(retry: true));
      final more = await bloc.stream.firstWhere((s) => s.cafes.length == 25);
      expect(more.loadMoreFailed, isFalse);
      expect(more.hasReachedMax, isTrue);
      expect(more.page, 1);
    });

    test('a failed first page is still the full error state', () async {
      search.answer = (_) => throw Exception('offline');
      final bloc = build();
      bloc.add(const SearchTagsChanged({'Free WiFi'}));
      final state = await bloc.stream.firstWhere(
        (s) => s.status == SearchStatus.failure,
      );
      expect(state.loadMoreFailed, isFalse);
      expect(state.cafes, isEmpty);
    });
  });

  test('the same query can be run again after it failed (S-8)', () async {
    search.answer = (_) => throw Exception('offline');
    final bloc = build();
    bloc.add(const SearchQueryChanged('matcha'));
    await bloc.stream.firstWhere((s) => s.status == SearchStatus.failure);

    search.answer = (_) => const [_cafe];
    bloc.add(const SearchQueryChanged('matcha'));
    final state = await bloc.stream.firstWhere(
      (s) => s.status == SearchStatus.success,
    );
    expect(state.cafes, [_cafe]);
    expect(search.queries, hasLength(2));
  });

  group('countFor', () {
    test('counts the search run with the draft tags', () async {
      search.answer = (q) => List.filled(q.tags.length == 2 ? 12 : 3, _cafe);
      final bloc = build();
      await searchByTag(bloc);

      expect(await bloc.countFor({'Free WiFi', 'Power Outlets'}), 12);
      final counted = search.queries.last;
      expect(counted.tags, ['Free WiFi', 'Power Outlets']);
      expect(counted.page, 0);
      expect(counted.limit, SearchBloc.countLimit);
      // The draft is not applied by counting it.
      expect(bloc.state.tags, {'Free WiFi'});
    });

    test('is null when the page came back full', () async {
      final bloc = build();
      await searchByTag(bloc);
      search.answer = (_) => List.filled(SearchBloc.countLimit, _cafe);
      expect(await bloc.countFor({'Free WiFi'}), isNull);
    });

    test('is null when there would be nothing to search', () async {
      final bloc = build();
      expect(await bloc.countFor(const {}), isNull);
      expect(search.queries, isEmpty);
    });

    test('open now is applied to the count as it is to the results', () async {
      final bloc = build();
      await searchByTag(bloc);
      bloc.add(const SearchOpenNowToggled());
      await bloc.stream.firstWhere((s) => s.openNow);
      // The fake cafe has no hours, so it is not open.
      expect(await bloc.countFor({'Free WiFi'}), 0);
    });

    test('a failed count throws, so the sheet keeps "Apply"', () async {
      final bloc = build();
      await searchByTag(bloc);
      search.answer = (_) => throw Exception('offline');
      await expectLater(bloc.countFor({'Free WiFi'}), throwsException);
    });
  });

  group('shared origin', () {
    test('search opens on the place the map chose', () {
      final store = SearchOriginStore()..set(_itPark);
      expect(build(store: store).state.origin, _itPark);
    });

    test('choosing or resetting a place in search tells the map', () async {
      final store = SearchOriginStore();
      final bloc = build(store: store);
      final seen = <SearchOrigin?>[];
      store.origin.addListener(() => seen.add(store.value));

      bloc.add(const SearchOriginChanged(_itPark));
      await bloc.stream.firstWhere((s) => s.origin == _itPark);
      bloc.add(const SearchOriginChanged(null));
      await bloc.stream.firstWhere((s) => s.origin == null);

      expect(seen, [_itPark, null]);
    });
  });
}
