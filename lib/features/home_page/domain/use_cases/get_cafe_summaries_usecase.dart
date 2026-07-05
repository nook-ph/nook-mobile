import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

typedef HomeFeedResult = ({
  List<CafeSummary> nearby,
  List<CafeSummary> topRated,
  List<CafeSummary> trending,
  List<CafeSummary> newest,
});

typedef HomeFeedWithLocationMeta = ({HomeFeedResult feed, bool locationDenied});

class GetHomeFeedUseCase {
  final ICafeRepository repository;

  GetHomeFeedUseCase(this.repository);

  Future<HomeFeedWithLocationMeta> call({int page = 0, int limit = 20}) async {
    final locFuture = _resolveLocation();
    final topRatedFuture = _safeFetch(
      label: 'top_rated',
      query: CafeQuery(
        sort: 'top_rated',
        lat: null,
        lng: null,
        page: page,
        limit: limit,
      ),
    );
    final trendingFuture = _safeFetch(
      label: 'trending',
      query: CafeQuery(
        sort: 'trending',
        lat: null,
        lng: null,
        page: page,
        limit: limit,
      ),
    );
    final newestFuture = _safeFetch(
      label: 'newest',
      query: CafeQuery(
        sort: 'newest',
        lat: null,
        lng: null,
        page: page,
        limit: limit,
      ),
    );

    final results = await Future.wait<dynamic>([
      locFuture,
      topRatedFuture,
      trendingFuture,
      newestFuture,
    ]);
    final loc = results[0] as ({Position? position, bool locationDenied});
    final topRated = results[1] as List<CafeSummary>;
    final trending = results[2] as List<CafeSummary>;
    final newest = results[3] as List<CafeSummary>;

    final nearby = loc.position == null
        ? <CafeSummary>[]
        : await _safeFetch(
            label: 'nearby',
            query: CafeQuery(
              sort: 'nearby',
              lat: loc.position?.latitude,
              lng: loc.position?.longitude,
              page: page,
              limit: limit,
            ),
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
      return await repository.getCafes(query);
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

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return (
          position: null,
          locationDenied: permission == LocationPermission.deniedForever,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 100,
        ),
      ).timeout(const Duration(seconds: 4));
      return (position: position, locationDenied: false);
    } on TimeoutException {
      return (position: null, locationDenied: false);
    } catch (_) {
      return (position: null, locationDenied: false);
    }
  }
}
