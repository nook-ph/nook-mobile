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

  /// The most rows one viewport fetch returns (the data source's map fetch
  /// limit). A result this long may have been cut off, so its length is not
  /// a count of the cafes in view.
  static const int fetchCap = 1000;

  final ICafeRepository repository;

  GetCafesForViewportUseCase(this.repository);

  /// Whether a fetch for [fetched] already returned every cafe [next] can
  /// show: both use the fixed circle, and all of [next] lies inside the
  /// circle that was fetched. Only holds for a result under [fetchCap].
  static bool covers({
    required MapViewport fetched,
    required MapViewport next,
  }) {
    if (viewportRadiusMeters(fetched) > radiusMeters) return false;
    final reach =
        haversineMeters(fetched.center, next.center) +
        viewportRadiusMeters(next);
    return reach <= radiusMeters;
  }

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
