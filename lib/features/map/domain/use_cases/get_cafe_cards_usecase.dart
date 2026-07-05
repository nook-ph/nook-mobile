import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/filters/models/cafe_filter.dart';
import 'package:geolocator/geolocator.dart';

typedef CafeCardResult = ({
  List<CafeSummary> cafes,
  bool locationDenied,
});

class GetCafeCardUseCase {
  final ICafeRepository repository;
  GetCafeCardUseCase(this.repository);

  Future<CafeCardResult> call({
    int page = 0,
    int limit = 20,
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
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (lat: null, lng: null, locationDenied: false);
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return (
          lat: null,
          lng: null,
          locationDenied: permission == LocationPermission.deniedForever,
        );
      }

      final location = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 3));
      return (
        lat: location.latitude,
        lng: location.longitude,
        locationDenied: false,
      );
    } catch (_) {
      return (lat: null, lng: null, locationDenied: false);
    }
  }
}
