import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/core/utils/geo.dart';

/// Fetches the cafes to show for the current map viewport.
///
/// When the whole visible area fits inside [radiusMeters] we fetch a fixed
/// circle around the map center; once the view is larger we fetch the exact
/// bounds. Mirrors the webapp's `MapExplorer.fetchForViewport`.
class GetCafesForViewportUseCase {
  static const double radiusMeters = 20000; // 20 km

  final ICafeRepository repository;

  GetCafesForViewportUseCase(this.repository);

  Future<List<CafeSummary>> call({
    required MapViewport viewport,
    CafeFilter filter = const CafeFilter(),
  }) async {
    final tags = filter.tagNames.toList();

    final List<CafeSummary> cafes;
    if (viewportRadiusMeters(viewport) <= radiusMeters) {
      cafes = await repository.getCafesNearPoint(
        lat: viewport.center.lat,
        lng: viewport.center.lng,
        radiusMeters: radiusMeters,
        query: filter.query,
        tags: tags,
        sort: filter.sort,
      );
    } else {
      cafes = await repository.getCafesInViewport(
        bounds: viewport.bounds,
        query: filter.query,
        tags: tags,
        sort: filter.sort,
        // Distance-based sorts need a reference point; use the map center.
        lat: viewport.center.lat,
        lng: viewport.center.lng,
      );
    }

    await repository.warmCache(cafes);
    return cafes;
  }
}
