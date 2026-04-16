import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/entities/cafe_query.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:geolocator/geolocator.dart';

typedef CafeCardResult = ({List<CafeSummary> cafes});

class GetCafeCardUseCase {
  final ICafeRepository repository;
  GetCafeCardUseCase(this.repository);

  Future<CafeCardResult> call({int page = 0, int limit = 20, List<String> tags = const[]}) async {
    final location = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final cafes = await repository.getCafes(
      CafeQuery(
        sort: 'nearby',
        tags: tags,
        lat: location.latitude,
        lng: location.longitude,
        page: page,
        limit: limit,
      ),
    );

    await repository.warmCache(cafes);

    return (cafes: cafes);
  }
}
