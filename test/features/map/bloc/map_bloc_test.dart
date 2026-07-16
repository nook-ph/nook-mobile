import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/core/utils/geo.dart';
import 'package:nook/features/map/bloc/map_bloc.dart';
import 'package:nook/features/map/bloc/map_event.dart';
import 'package:nook/features/map/bloc/map_states.dart';
import 'package:nook/features/map/domain/entities/cafe_tags_entity.dart';
import 'package:nook/features/map/domain/repositories/i_cafe_tags_repository.dart';
import 'package:nook/features/map/domain/use_cases/get_cafe_cards_usecase.dart';
import 'package:nook/features/map/domain/use_cases/get_cafes_for_viewport_usecase.dart';
import 'package:nook/features/map/domain/use_cases/get_filter_tags_usecase.dart';

const _initialCafe = CafeSummary(id: 'initial', name: 'Initial', rating: 4);
const _viewportCafe = CafeSummary(id: 'nearby', name: 'Nearby', rating: 5);

const _viewport = MapViewport(
  center: GeoPoint(lat: 10.3167, lng: 123.8907),
  bounds: MapBounds(north: 10.4, east: 124.0, south: 10.2, west: 123.8),
  zoom: 13,
);

/// Waits out the bloc's viewport debounce plus a little slack.
Future<void> _settleDebounce() => Future<void>.delayed(
  MapBloc.viewportDebounce + const Duration(milliseconds: 150),
);

MapBloc _buildBloc({
  required _FakeViewportUseCase viewportUseCase,
  _FakeCardUseCase? cardUseCase,
}) {
  return MapBloc(
    getCafeCardUseCase: cardUseCase ?? _FakeCardUseCase(),
    getFilterTagsUseCase: _FakeFilterTagsUseCase(),
    getCafesForViewportUseCase: viewportUseCase,
  );
}

Future<void> _loadInitial(MapBloc bloc) async {
  bloc.add(LoadMapDataEvent());
  await expectLater(bloc.stream, emitsThrough(isA<MapLoadedState>()));
}

void main() {
  test(
    'initial load emits loading then loaded with the fetched cafes',
    () async {
      final bloc = _buildBloc(viewportUseCase: _FakeViewportUseCase());
      addTearDown(bloc.close);

      bloc.add(LoadMapDataEvent());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<MapLoadingState>(),
          isA<MapLoadedState>().having((s) => s.cafes, 'cafes', [_initialCafe]),
        ]),
      );
    },
  );

  test('viewport changes before the initial load are ignored', () async {
    final viewportUseCase = _FakeViewportUseCase();
    final bloc = _buildBloc(viewportUseCase: viewportUseCase);
    addTearDown(bloc.close);

    bloc.add(MapViewportChangedEvent(_viewport));
    await _settleDebounce();

    expect(viewportUseCase.calls, isEmpty);
    expect(bloc.state, isA<MapInitialState>());
  });

  test('a viewport change refetches after the debounce, showing the refresh '
      'chip and then the new cafes', () async {
    final viewportUseCase = _FakeViewportUseCase();
    final bloc = _buildBloc(viewportUseCase: viewportUseCase);
    addTearDown(bloc.close);
    await _loadInitial(bloc);

    final emitted = <MapState>[];
    final sub = bloc.stream.listen(emitted.add);
    addTearDown(sub.cancel);

    bloc.add(MapViewportChangedEvent(_viewport));
    await _settleDebounce();

    expect(viewportUseCase.calls, hasLength(1));
    expect(
      emitted,
      containsAllInOrder([
        isA<MapLoadedState>()
            .having((s) => s.isRefreshing, 'isRefreshing', true)
            .having((s) => s.cafes, 'cafes (kept while loading)', [
              _initialCafe,
            ]),
        isA<MapLoadedState>()
            .having((s) => s.isRefreshing, 'isRefreshing', false)
            .having((s) => s.cafes, 'cafes', [_viewportCafe]),
      ]),
    );
  });

  test('rapid viewport changes are debounced into one fetch', () async {
    final viewportUseCase = _FakeViewportUseCase();
    final bloc = _buildBloc(viewportUseCase: viewportUseCase);
    addTearDown(bloc.close);
    await _loadInitial(bloc);

    for (var i = 0; i < 5; i++) {
      bloc.add(MapViewportChangedEvent(_viewport));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    await _settleDebounce();

    expect(viewportUseCase.calls, hasLength(1));
  });

  test('a refetch error keeps the previous cafes and drops the chip', () async {
    final viewportUseCase = _FakeViewportUseCase(failNext: true);
    final bloc = _buildBloc(viewportUseCase: viewportUseCase);
    addTearDown(bloc.close);
    await _loadInitial(bloc);

    bloc.add(MapViewportChangedEvent(_viewport));
    await _settleDebounce();

    final state = bloc.state;
    expect(state, isA<MapLoadedState>());
    state as MapLoadedState;
    expect(state.cafes, [_initialCafe]);
    expect(state.isRefreshing, false);
  });

  test('applying a filter after the map has a viewport refetches that '
      'viewport immediately with the new filter', () async {
    final viewportUseCase = _FakeViewportUseCase();
    final bloc = _buildBloc(viewportUseCase: viewportUseCase);
    addTearDown(bloc.close);
    await _loadInitial(bloc);

    // The map reported a viewport at some point.
    bloc.add(MapViewportChangedEvent(_viewport));
    await _settleDebounce();
    expect(viewportUseCase.calls, hasLength(1));

    const filter = CafeFilter(tagNames: {'Quiet'}, sort: 'top_rated');
    bloc.add(LoadMapDataEvent(filter: filter));
    // No debounce on filter application — only the microtask queue to drain.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(viewportUseCase.calls, hasLength(2));
    expect(viewportUseCase.calls.last.filter, filter);
    expect(viewportUseCase.calls.last.viewport, _viewport);
  });
}

class _ViewportCall {
  _ViewportCall(this.viewport, this.filter);
  final MapViewport viewport;
  final CafeFilter filter;
}

class _FakeViewportUseCase extends GetCafesForViewportUseCase {
  _FakeViewportUseCase({this.failNext = false}) : super(_StubRepository());

  bool failNext;
  final calls = <_ViewportCall>[];

  @override
  Future<List<CafeSummary>> call({
    required MapViewport viewport,
    CafeFilter filter = const CafeFilter(),
  }) async {
    calls.add(_ViewportCall(viewport, filter));
    if (failNext) {
      failNext = false;
      throw Exception('viewport fetch failed');
    }
    return const [_viewportCafe];
  }
}

class _FakeCardUseCase extends GetCafeCardUseCase {
  _FakeCardUseCase() : super(_StubRepository());

  @override
  Future<CafeCardResult> call({
    int page = 0,
    int limit = 20,
    CafeFilter filter = const CafeFilter(),
  }) async {
    return (cafes: const <CafeSummary>[_initialCafe], locationDenied: false);
  }
}

class _FakeFilterTagsUseCase extends GetFilterTagsUseCase {
  _FakeFilterTagsUseCase() : super(_StubTagsRepository());

  @override
  Future<List<CafeTagsEntity>> call() async => const [];
}

class _StubRepository implements ICafeRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _StubTagsRepository implements ICafeTagsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
