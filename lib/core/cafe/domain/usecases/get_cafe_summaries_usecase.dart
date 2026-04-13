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

    final nearbyFuture = location == null
        ? Future.value(<CafeSummary>[])
        : repository.getCafes(
            CafeQuery(
              sort: 'nearby',
              lat: location.latitude,
              lng: location.longitude,
              page: page,
              limit: limit,
            ),
          );

    final results = await Future.wait([
      nearbyFuture,
      repository.getCafes(
        CafeQuery(sort: 'top_rated', page: page, limit: limit),
      ),
      repository.getCafes(
        CafeQuery(sort: 'trending', page: page, limit: limit),
      ),
      repository.getCafes(CafeQuery(sort: 'newest', page: page, limit: limit)),
    ]);

    final nearby = results[0];
    final topRated = results[1];
    final trending = results[2];
    final newest = results[3];

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

  Future<Position?> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      );
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
