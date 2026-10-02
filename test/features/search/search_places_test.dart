import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/features/search/bloc/search_bloc.dart';
import 'package:nook/features/search/data/search_places.dart';
import 'package:nook/features/search/domain/use_cases/search_cafes_usecase.dart';

/// What `get_cafes` accepts for `p_limit`; anything above is an error.
const _serverMaxLimit = 100;

class _StubRepository implements ICafeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Serves [cafes] in pages and rejects a limit the server would reject.
class _PagedSearch extends SearchCafesUseCase {
  _PagedSearch(this.cafes) : super(_StubRepository());

  final List<CafeSummary> cafes;
  final queries = <CafeQuery>[];

  @override
  Future<List<CafeSummary>> call(CafeQuery query) async {
    queries.add(query);
    if (query.limit < 1 || query.limit > _serverMaxLimit) {
      throw Exception('p_limit must be between 1 and 100');
    }
    return cafes.skip(query.offset).take(query.limit).toList();
  }
}

CafeSummary _cafe(int i, String neighborhood) => CafeSummary(
  id: 'c$i',
  name: 'Cafe $i',
  rating: 4,
  neighborhood: neighborhood,
  city: 'Cebu City',
  lat: 10.3 + i * 0.0001,
  lng: 123.9,
);

void main() {
  test('the place index is built within the server page limit (S-2)', () async {
    final search = _PagedSearch([
      for (var i = 0; i < 40; i++) _cafe(i, 'Lahug'),
    ]);

    final index = await SearchPlaces(search).index();

    expect(search.queries, hasLength(1));
    expect(search.queries.single.limit, lessThanOrEqualTo(_serverMaxLimit));
    expect(index.match('Lahug').map((p) => p.label), contains('Lahug'));
  });

  test('more cafes than one page are all read', () async {
    final search = _PagedSearch([
      for (var i = 0; i < 100; i++) _cafe(i, 'Lahug'),
      for (var i = 100; i < 230; i++) _cafe(i, 'Banilad'),
      _cafe(230, 'Mabolo'),
    ]);

    final index = await SearchPlaces(search).index();

    expect(search.queries.map((q) => q.page), [0, 1, 2]);
    expect(index.match('Mabolo'), isNotEmpty);
    expect(index.match('Banilad'), isNotEmpty);
  });

  test('a failed build is retried on the next ask', () async {
    final search = _PagedSearch([_cafe(1, 'Lahug')]);
    final places = SearchPlaces(_FailingOnce(search));

    await expectLater(places.index(), throwsException);
    expect((await places.index()).match('Lahug'), isNotEmpty);
  });

  test('the filter count asks for no more than the server allows (S-3)', () {
    expect(SearchBloc.countLimit, lessThanOrEqualTo(_serverMaxLimit));
  });
}

class _FailingOnce extends SearchCafesUseCase {
  _FailingOnce(this._inner) : super(_StubRepository());

  final SearchCafesUseCase _inner;
  var _failed = false;

  @override
  Future<List<CafeSummary>> call(CafeQuery query) async {
    if (!_failed) {
      _failed = true;
      throw Exception('offline');
    }
    return _inner.call(query);
  }
}
