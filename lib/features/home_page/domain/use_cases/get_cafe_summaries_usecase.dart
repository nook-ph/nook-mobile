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

/// One step of a home load. [nearbyPending] marks the early step: the
/// location-free sections are in, the position (and so "Near you") is not.
typedef HomeFeedUpdate = ({HomeFeedWithLocationMeta data, bool nearbyPending});

class GetHomeFeedUseCase {
  final ICafeRepository repository;
  final Future<LocationAccess> Function() _locationAccess;
  final Future<Position?> Function() _firstPosition;

  GetHomeFeedUseCase(
    this.repository, {
    Future<LocationAccess> Function()? locationAccess,
    Future<Position?> Function()? firstPosition,
  }) : _locationAccess = locationAccess ?? DeviceLocation.instance.access,
       _firstPosition = firstPosition ?? DeviceLocation.instance.first;

  /// The whole feed in one answer. See [watch] for the staged version.
  Future<HomeFeedWithLocationMeta> call({int page = 0, int limit = 20}) async {
    return (await watch(page: page, limit: limit).last).data;
  }

  /// Each section is fetched on its own, so one failing leaves the others on
  /// screen. When every section that was asked for failed there is no feed to
  /// show, and the first error is thrown: an empty result then always means
  /// "loaded, and there is nothing", never "everything broke".
  ///
  /// A position can take seconds, and three of the four sections do not need
  /// one. When they arrive before it they are handed over on their own, and
  /// the full feed follows once "Near you" has been fetched (or ruled out).
  Stream<HomeFeedUpdate> watch({int page = 0, int limit = 20}) async* {
    final failures = <Object>[];
    var attempted = 3;
    final accessFuture = _readAccess();
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

    // "Near you" starts the moment there is a position, alongside the other
    // sections rather than after them.
    Position? position;
    var positionResolved = false;
    final nearbyFuture = accessFuture.then((access) async {
      if (!access.servicesOff && !access.denied) {
        position = await _readPosition();
      }
      positionResolved = true;
      final at = position;
      if (at == null) return <CafeSummary>[];
      return _safeFetch(
        label: 'nearby',
        failures: failures,
        query: CafeQuery(
          sort: 'nearby',
          lat: at.latitude,
          lng: at.longitude,
          page: page,
          limit: limit,
        ),
      );
    });

    final access = await accessFuture;
    final sections = await Future.wait([
      topRatedFuture,
      trendingFuture,
      newestFuture,
    ]);
    final topRated = sections[0];
    final trending = sections[1];
    final newest = sections[2];

    // Still waiting on a fix: show what there is. With the position already
    // in, "Near you" is one round trip behind at most, and waiting for it
    // saves the feed from shifting under the reader.
    if (!positionResolved && sections.any((cafes) => cafes.isNotEmpty)) {
      await repository.warmCache([...topRated, ...trending, ...newest]);
      yield (
        data: (
          feed: (
            nearby: <CafeSummary>[],
            topRated: topRated,
            trending: trending,
            newest: newest,
          ),
          locationDenied: access.deniedForever,
          locationServicesOff: access.servicesOff,
        ),
        nearbyPending: true,
      );
    }

    final nearby = await nearbyFuture;
    if (position != null) attempted++;

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

    yield (
      data: (
        feed: feed,
        locationDenied: access.deniedForever,
        locationServicesOff: access.servicesOff,
      ),
      nearbyPending: false,
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

  Future<LocationAccess> _readAccess() async {
    try {
      return await _locationAccess();
    } catch (_) {
      return (servicesOff: false, denied: true, deniedForever: false);
    }
  }

  Future<Position?> _readPosition() async {
    try {
      return await _firstPosition();
    } catch (_) {
      return null;
    }
  }
}
