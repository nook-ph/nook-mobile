import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:geolocator/geolocator.dart';

typedef HomeFeedResult = ({
  List<CafeSummary> nearby,
  List<CafeSummary> topRated,
  List<CafeSummary> trending,
  List<CafeSummary> newest,
});

class GetHomeFeedUseCase {
  final ICafeRepository repository;

  GetHomeFeedUseCase(this.repository);

  Future<HomeFeedResult> call({int page = 0, int limit = 20}) async {
    final location = await _resolveLocation();

    final nearby = location == null
        ? <CafeSummary>[]
        : await _safeFetch(
            label: 'nearby',
            query: CafeQuery(
              sort: 'nearby',
              lat: location.latitude,
              lng: location.longitude,
              page: page,
              limit: limit,
            ),
          );

    final topRated = await _safeFetch(
      label: 'top_rated',
      query: CafeQuery(sort: 'top_rated', page: page, limit: limit),
    );

    final trending = await _safeFetch(
      label: 'trending',
      query: CafeQuery(sort: 'trending', page: page, limit: limit),
    );

    final newest = await _safeFetch(
      label: 'newest',
      query: CafeQuery(sort: 'newest', page: page, limit: limit),
    );

    await repository.warmCache([
      ...nearby,
      ...topRated,
      ...trending,
      ...newest,
    ]);

    return (
      nearby: nearby,
      topRated: topRated,
      trending: trending,
      newest: newest,
    );
  }

  Future<List<CafeSummary>> _safeFetch({
    required String label,
    required CafeQuery query,
  }) async {
    try {
      final cafes = await repository.getCafes(query);
      return cafes;
    } catch (_) {
      return <CafeSummary>[];
    }
  }

  Future<Position?> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      );
      return position;
    } catch (_) {
      return null;
    }
  }
}

// @Deprecated('Use GetHomeFeedUseCase.')
// typedef CafeSummariesResult = ({
//   List<CafeSummary> featured,
//   List<CafeSummary> recommended,
// });

// @Deprecated('Use GetHomeFeedUseCase.')
// class GetCafeSummariesUseCase {
//   final GetHomeFeedUseCase _homeFeedUseCase;

//   GetCafeSummariesUseCase(ICafeRepository repository)
//     : _homeFeedUseCase = GetHomeFeedUseCase(repository);

//   Future<CafeSummariesResult> call({int page = 0, int limit = 20}) async {
//     final result = await _homeFeedUseCase(page: page, limit: limit);

//     return (featured: result.trending, recommended: result.topRated);
//   }
// }
