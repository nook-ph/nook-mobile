import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:nook/core/location/device_location.dart';

typedef CafeCardResult = ({List<CafeSummary> cafes, bool locationDenied});

class GetCafeCardUseCase {
  final ICafeRepository repository;
  GetCafeCardUseCase(this.repository);

  /// Rows the first map load asks for. A full page may have been cut off.
  static const int defaultLimit = 20;

  Future<CafeCardResult> call({
    int page = 0,
    int limit = defaultLimit,
    CafeFilter filter = const CafeFilter(),
  }) async {
    double? lat = filter.lat;
    double? lng = filter.lng;
    var locationDenied = false;

    if (lat == null || lng == null) {
      final resolved = await _resolveDeviceCoordinates();
      lat = resolved.lat;
      lng = resolved.lng;
      locationDenied = resolved.locationDenied;
    }

    final resolvedSort =
        (filter.sort == 'nearby' && (lat == null || lng == null))
        ? 'top_rated'
        : filter.sort;

    final cafes = await repository.getCafes(
      CafeQuery(
        query: filter.query,
        sort: resolvedSort,
        tags: filter.tagNames.toList(),
        lat: lat,
        lng: lng,
        page: page,
        limit: limit,
      ),
    );

    await repository.warmCache(cafes);

    return (cafes: cafes, locationDenied: locationDenied);
  }

  Future<({double? lat, double? lng, bool locationDenied})>
  _resolveDeviceCoordinates() async {
    // The shared device position: the last known one answers at once, where
    // a fresh fix of this use case's own could hold the first pins for
    // seconds.
    final access = await DeviceLocation.instance.access();
    if (access.servicesOff || access.denied) {
      return (lat: null, lng: null, locationDenied: access.deniedForever);
    }
    final location = await DeviceLocation.instance.first();
    return (
      lat: location?.latitude,
      lng: location?.longitude,
      locationDenied: false,
    );
  }
}
