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

typedef HomeFeedWithLocationMeta = ({
  HomeFeedResult feed,
  bool locationDenied,
});

class GetHomeFeedUseCase {
  final ICafeRepository repository;

  GetHomeFeedUseCase(this.repository);

  Future<HomeFeedWithLocationMeta> call({int page = 0, int limit = 20}) async {
    final loc = await _resolveLocation();

    final nearby = loc.position == null
        ? <CafeSummary>[]
        : await _safeFetch(
            label: 'nearby',
            query: CafeQuery(
              sort: 'nearby',
              lat: loc.position!.latitude,
              lng: loc.position!.longitude,
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

    final feed = (
      nearby: nearby,
      topRated: topRated,
      trending: trending,
      newest: newest,
    );

    await repository.warmCache([
      ...nearby,
      ...topRated,
      ...trending,
      ...newest,
    ]);

    return (feed: feed, locationDenied: loc.locationDenied);
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

  Future<({Position? position, bool locationDenied})> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (position: null, locationDenied: false);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (position: null, locationDenied: true);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      );
      return (position: position, locationDenied: false);
    } catch (_) {
      return (position: null, locationDenied: false);
    }
  }
}
