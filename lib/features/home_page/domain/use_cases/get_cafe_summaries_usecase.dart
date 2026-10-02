import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/location/device_location.dart';

typedef HomeFeedResult = ({
  List<CafeSummary> nearby,
  List<CafeSummary> topRated,
  List<CafeSummary> trending,
  List<CafeSummary> newest,
});

/// [locationDenied] is the permanently-denied permission case;
/// [locationServicesOff] is the phone-wide Location Services switch. Either
/// one means no position, so no nearby list and no distances.
typedef HomeFeedWithLocationMeta = ({
  HomeFeedResult feed,
  bool locationDenied,
  bool locationServicesOff,
});

typedef _ResolvedLocation = ({
  Position? position,
  bool locationDenied,
  bool servicesOff,
});

class GetHomeFeedUseCase {
  final ICafeRepository repository;

  GetHomeFeedUseCase(this.repository);

  /// Each section is fetched on its own, so one failing leaves the others on
  /// screen. When every section that was asked for failed there is no feed to
  /// show, and the first error is rethrown: an empty result then always means
  /// "loaded, and there is nothing", never "everything broke".
  Future<HomeFeedWithLocationMeta> call({int page = 0, int limit = 20}) async {
    final failures = <Object>[];
    var attempted = 3;
    final locFuture = _resolveLocation();
    final topRatedFuture = _safeFetch(
      label: 'top_rated',
      failures: failures,
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
      failures: failures,
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
      failures: failures,
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
    final loc = results[0] as _ResolvedLocation;
    final topRated = results[1] as List<CafeSummary>;
    final trending = results[2] as List<CafeSummary>;
    final newest = results[3] as List<CafeSummary>;

    if (loc.position != null) attempted++;
    final nearby = loc.position == null
        ? <CafeSummary>[]
        : await _safeFetch(
            label: 'nearby',
            failures: failures,
            query: CafeQuery(
              sort: 'nearby',
              lat: loc.position?.latitude,
              lng: loc.position?.longitude,
              page: page,
              limit: limit,
            ),
          );

    if (failures.length >= attempted) {
      throw failures.first;
    }

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

    return (
      feed: feed,
      locationDenied: loc.locationDenied,
      locationServicesOff: loc.servicesOff,
    );
  }

  Future<List<CafeSummary>> _safeFetch({
    required String label,
    required List<Object> failures,
    required CafeQuery query,
  }) async {
    try {
      return await repository.getCafes(query);
    } catch (e) {
      failures.add(e);
      return <CafeSummary>[];
    }
  }

  Future<_ResolvedLocation> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (position: null, locationDenied: false, servicesOff: true);
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return (
          position: null,
          locationDenied: permission == LocationPermission.deniedForever,
          servicesOff: false,
        );
      }

      // The app-wide position: it falls back to the last known fix when a
      // fresh one is slow, where a bare request would time out and drop the
      // "Near you" section. It is also what the cards measure from.
      final position = await DeviceLocation.instance.ensure();
      return (position: position, locationDenied: false, servicesOff: false);
    } on TimeoutException {
      return (position: null, locationDenied: false, servicesOff: false);
    } catch (_) {
      return (position: null, locationDenied: false, servicesOff: false);
    }
  }
}
