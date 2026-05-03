import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class GetCafeListMembershipsUseCase {
  final ICafeRepository repository;

  const GetCafeListMembershipsUseCase(this.repository);

  Future<Set<String>> call(String cafeId, List<String> listIds) {
    return repository.getCafeListMemberships(cafeId, listIds);
  }
}
