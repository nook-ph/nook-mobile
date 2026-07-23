import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class SetCafeStatusUseCase {
  final ICafeRepository repository;

  const SetCafeStatusUseCase(this.repository);

  Future<CafeStatus> call(String cafeId, CafeStatus status) {
    return repository.setCafeStatus(cafeId, status);
  }
}
