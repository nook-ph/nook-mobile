import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final session = Supabase.instance.client.auth.currentSession;
    final accessToken = session?.accessToken;
    final userId = session?.user.id;
    debugPrint(
      '[GetHomeFeed] start; '
      'hasSession=${session != null} '
      'accessTokenLen=${accessToken?.length} '
      'userId=$userId',
    );

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

    debugPrint(
      '[GetHomeFeed] non-nearby fetched; '
      'topRated=${topRated.length} '
      'trending=${trending.length} '
      'newest=${newest.length} '
      'hasPosition=${loc.position != null} '
      'locationDenied=${loc.locationDenied}',
    );

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
      final cafes = await repository.getCafes(query);
      debugPrint(
        '[GetHomeFeed] _safeFetch($label) ok; '
        'count=${cafes.length} '
        'sort=${query.sort} '
        'hasLatLng=${query.lat != null && query.lng != null}',
      );
      return cafes;
    } catch (e, st) {
      debugPrint(
        '[GetHomeFeed] _safeFetch($label) FAILED; '
        'sort=${query.sort} '
        'errorType=${e.runtimeType} '
        'error=$e\n$st',
      );
      return <CafeSummary>[];
    }
  }

  Future<({Position? position, bool locationDenied})> _resolveLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('[GetHomeFeed] _resolveLocation: serviceEnabled=$serviceEnabled');
      if (!serviceEnabled) {
        return (position: null, locationDenied: false);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      debugPrint('[GetHomeFeed] _resolveLocation: permission=$permission');

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return (position: null, locationDenied: true);
      }

      debugPrint(
        '[GetHomeFeed] _resolveLocation: requesting position '
        '(medium, 4s timeout)…',
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 100,
        ),
      ).timeout(const Duration(seconds: 4));
      debugPrint('[GetHomeFeed] _resolveLocation: got position');
      return (position: position, locationDenied: false);
    } on TimeoutException {
      debugPrint(
        '[GetHomeFeed] _resolveLocation: TIMEOUT after 4s — '
        'proceeding without position',
      );
      return (position: null, locationDenied: false);
    } catch (e, st) {
      debugPrint('[GetHomeFeed] _resolveLocation: error: $e\n$st');
      return (position: null, locationDenied: false);
    }
  }
}
