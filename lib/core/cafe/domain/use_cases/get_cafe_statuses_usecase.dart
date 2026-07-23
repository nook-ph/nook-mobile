import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class GetCafeStatusesUseCase {
  final ICafeRepository repository;

  const GetCafeStatusesUseCase(this.repository);

  /// Batch lookup; cafes with no status are absent from the result map.
  Future<Map<String, CafeStatus>> call(List<String> cafeIds) {
    return repository.getCafeStatuses(cafeIds);
  }
}
