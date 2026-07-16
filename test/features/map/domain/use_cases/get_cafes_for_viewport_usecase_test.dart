import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/core/utils/geo.dart';
import 'package:nook/features/map/domain/use_cases/get_cafes_for_viewport_usecase.dart';

void main() {
  // Roughly how many degrees of latitude one meter covers.
  const degPerMeterLat = 1 / 111320;

  MapViewport viewportWithRadius(double meters) {
    const center = GeoPoint(lat: 10.3167, lng: 123.8907);
    final dLat = meters * degPerMeterLat;
    // Corner offset only on latitude so the radius is exactly `meters`.
    return MapViewport(
      center: center,
      bounds: MapBounds(
        north: center.lat + dLat,
        east: center.lng,
        south: center.lat - dLat,
        west: center.lng,
      ),
      zoom: 12,
    );
  }

  test(
    'fetches a fixed 20km circle when the viewport fits inside it',
    () async {
      final repo = _RecordingRepository();
      final useCase = GetCafesForViewportUseCase(repo);

      final viewport = viewportWithRadius(5000);
      await useCase.call(
        viewport: viewport,
        filter: const CafeFilter(query: 'matcha', tagNames: {'Quiet'}),
      );

      expect(repo.nearPointCalls, hasLength(1));
      expect(repo.viewportCalls, isEmpty);
      final call = repo.nearPointCalls.single;
      expect(call.lat, viewport.center.lat);
      expect(call.lng, viewport.center.lng);
      expect(call.radiusMeters, GetCafesForViewportUseCase.radiusMeters);
      expect(call.query, 'matcha');
      expect(call.tags, ['Quiet']);
    },
  );

  test('fetches the exact bounds when zoomed out beyond the radius', () async {
    final repo = _RecordingRepository();
    final useCase = GetCafesForViewportUseCase(repo);

    final viewport = viewportWithRadius(50000);
    await useCase.call(viewport: viewport);

    expect(repo.nearPointCalls, isEmpty);
    expect(repo.viewportCalls, hasLength(1));
    final call = repo.viewportCalls.single;
    expect(call.bounds, viewport.bounds);
    // Distance sorts need a reference point — the map center is passed.
    expect(call.lat, viewport.center.lat);
    expect(call.lng, viewport.center.lng);
  });

  test(
    'a viewport exactly at the radius boundary uses the fixed circle',
    () async {
      final repo = _RecordingRepository();
      final useCase = GetCafesForViewportUseCase(repo);

      // Just inside the threshold (floating point keeps exact equality shaky).
      await useCase.call(viewport: viewportWithRadius(19999));

      expect(repo.nearPointCalls, hasLength(1));
      expect(repo.viewportCalls, isEmpty);
    },
  );

  test('warms the cafe cache with the fetched summaries', () async {
    final repo = _RecordingRepository(
      cafes: const [CafeSummary(id: 'c1', name: 'Cafe One', rating: 4.5)],
    );
    final useCase = GetCafesForViewportUseCase(repo);

    await useCase.call(viewport: viewportWithRadius(1000));

    expect(repo.warmedCafeIds, ['c1']);
  });
}

class _NearPointCall {
  _NearPointCall(this.lat, this.lng, this.radiusMeters, this.query, this.tags);
  final double lat;
  final double lng;
  final double radiusMeters;
  final String? query;
  final List<String> tags;
}

class _ViewportCall {
  _ViewportCall(this.bounds, this.lat, this.lng);
  final MapBounds bounds;
  final double? lat;
  final double? lng;
}

class _RecordingRepository implements ICafeRepository {
  _RecordingRepository({this.cafes = const []});

  final List<CafeSummary> cafes;
  final nearPointCalls = <_NearPointCall>[];
  final viewportCalls = <_ViewportCall>[];
  final warmedCafeIds = <String>[];

  @override
  Future<List<CafeSummary>> getCafesNearPoint({
    required double lat,
    required double lng,
    required double radiusMeters,
    String? query,
    List<String> tags = const [],
    String? sort,
  }) async {
    nearPointCalls.add(_NearPointCall(lat, lng, radiusMeters, query, tags));
    return cafes;
  }

  @override
  Future<List<CafeSummary>> getCafesInViewport({
    required MapBounds bounds,
    String? query,
    List<String> tags = const [],
    String? sort,
    double? lat,
    double? lng,
  }) async {
    viewportCalls.add(_ViewportCall(bounds, lat, lng));
    return cafes;
  }

  @override
  Future<void> warmCache(List<CafeSummary> summaries) async {
    warmedCafeIds.addAll(summaries.map((s) => s.id));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
