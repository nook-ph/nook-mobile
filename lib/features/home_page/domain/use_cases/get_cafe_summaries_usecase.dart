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
  List<CafeSummary> specialtyNearby,
  List<CafeSummary> laptopFriendly,
  List<CafeSummary> localBeans,
});

/// The existing tag behind "Specialty coffee near you". Tag names are the
/// filter keys, so this must match `tags.name` exactly.
const specialtyCoffeeTag = 'Specialty Coffee';

/// The coffee tag behind "Local beans" (docs COFFEE_TAGS.md §5). Until the
/// coffee migration is applied no cafe has it, the query comes back empty and
/// the shelf stays hidden.
const localBeansTag = 'Philippine Beans';

/// "Laptop-friendly" is derived: `get_cafes` matches every tag it is given,
/// so these two together are the shelf.
const laptopFriendlyTags = ['Free WiFi', 'Power Outlets'];

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
  /// A position can take seconds, and most sections do not need one. When they arrive before it they are handed over on their own, and
  /// the full feed follows once "Near you" has been fetched (or ruled out).
  Stream<HomeFeedUpdate> watch({int page = 0, int limit = 20}) async* {
    final failures = <Object>[];
    // The four location-free sections, plus Local beans once the position
    // is settled (nearby with one, top rated without).
    var attempted = 5;
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
    final laptopFuture = _safeFetch(
      label: 'laptop_friendly',
      failures: failures,
      query: CafeQuery(
        sort: 'top_rated',
        tags: laptopFriendlyTags,
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
    // "Specialty coffee near you" needs the position too: without one the
    // title would not be true, so the shelf is left out. "Local beans" makes
    // no distance claim: closest first with a position, top rated without.
    final nearbyFuture = accessFuture.then((access) async {
      if (!access.servicesOff && !access.denied) {
        position = await _readPosition();
      }
      positionResolved = true;
      final at = position;
      final localBeansFuture = _safeFetch(
        label: 'local_beans',
        failures: failures,
        query: CafeQuery(
          sort: at == null ? 'top_rated' : 'nearby',
          tags: const [localBeansTag],
          lat: at?.latitude,
          lng: at?.longitude,
          page: page,
          limit: limit,
        ),
      );
      if (at == null) {
        return (<CafeSummary>[], <CafeSummary>[], await localBeansFuture);
      }
      final both = await Future.wait([
        _safeFetch(
          label: 'nearby',
          failures: failures,
          query: CafeQuery(
            sort: 'nearby',
            lat: at.latitude,
            lng: at.longitude,
            page: page,
            limit: limit,
          ),
        ),
        _safeFetch(
          label: 'specialty_nearby',
          failures: failures,
          query: CafeQuery(
            sort: 'nearby',
            tags: const [specialtyCoffeeTag],
            lat: at.latitude,
            lng: at.longitude,
            page: page,
            limit: limit,
          ),
        ),
      ]);
      return (both[0], both[1], await localBeansFuture);
    });

    final access = await accessFuture;
    final sections = await Future.wait([
      topRatedFuture,
      trendingFuture,
      newestFuture,
      laptopFuture,
    ]);
    final topRated = sections[0];
    final trending = sections[1];
    final newest = sections[2];
    final laptop = sections[3];

    // Still waiting on a fix: show what there is. With the position already
    // in, "Near you" is one round trip behind at most, and waiting for it
    // saves the feed from shifting under the reader.
    if (!positionResolved && sections.any((cafes) => cafes.isNotEmpty)) {
      await repository.warmCache([
        ...topRated,
        ...trending,
        ...newest,
        ...laptop,
      ]);
      yield (
        data: (
          feed: (
            nearby: <CafeSummary>[],
            topRated: topRated,
            trending: trending,
            newest: newest,
            specialtyNearby: <CafeSummary>[],
            laptopFriendly: laptop,
            localBeans: <CafeSummary>[],
          ),
          locationDenied: access.deniedForever,
          locationServicesOff: access.servicesOff,
        ),
        nearbyPending: true,
      );
    }

    final (nearby, specialtyNearby, localBeans) = await nearbyFuture;
    if (position != null) attempted += 2;

    if (failures.length >= attempted) {
      throw failures.first;
    }

    final feed = (
      nearby: nearby,
      topRated: topRated,
      trending: trending,
      newest: newest,
      specialtyNearby: specialtyNearby,
      laptopFriendly: laptop,
      localBeans: localBeans,
    );

    await repository.warmCache([
      ...nearby,
      ...topRated,
      ...trending,
      ...newest,
      ...specialtyNearby,
      ...laptop,
      ...localBeans,
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
