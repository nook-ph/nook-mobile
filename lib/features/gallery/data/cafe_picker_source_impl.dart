import 'package:geolocator/geolocator.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/features/gallery/domain/i_cafe_picker_source.dart';

/// [ICafePickerSource] on the shared cafe repository: the Been system list,
/// `get_cafes` sorted by distance, and the map's near-point query.
class CafePickerSourceImpl implements ICafePickerSource {
  CafePickerSourceImpl({
    required ICafeRepository cafes,
    DeviceLocation? location,
  }) : _cafes = cafes,
       _location = location ?? DeviceLocation.instance;

  final ICafeRepository _cafes;
  final DeviceLocation _location;

  @override
  Future<List<CafeSummary>> beenCafes() async {
    final lists = await _cafes.getUserLists();
    final been = lists.where((l) => l.listType == 'been').firstOrNull;
    if (been == null) return const [];
    // Read newest first: the latest visit is the likeliest pick.
    return _cafes.getListCafes(been.id);
  }

  @override
  Future<List<CafeSummary>?> nearby({bool ask = false}) async {
    var access = await _location.access();
    if (ask && access.denied && !access.deniedForever && !access.servicesOff) {
      await Geolocator.requestPermission();
      access = await _location.access();
    }
    if (access.servicesOff || access.denied) return null;
    final position = await _location.ensure(forceRefresh: ask);
    if (position == null) return null;
    return _cafes.getCafes(
      CafeQuery(
        sort: 'nearby',
        lat: position.latitude,
        lng: position.longitude,
        limit: 6,
      ),
    );
  }

  @override
  Future<CafeSummary?> takenAt(
    double lat,
    double lng, {
    double maxMeters = 150,
  }) async {
    final cafes = await _cafes.getCafesNearPoint(
      lat: lat,
      lng: lng,
      radiusMeters: maxMeters,
      sort: 'nearby',
    );
    return cafes.firstOrNull;
  }

  @override
  Future<List<CafeSummary>> search(String query) {
    final text = query.trim();
    if (text.isEmpty) return Future.value(const []);
    return _cafes.getCafes(CafeQuery(query: text, limit: 20));
  }
}
