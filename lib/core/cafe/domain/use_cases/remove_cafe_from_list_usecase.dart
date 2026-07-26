import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class RemoveCafeFromListUseCase {
  final ICafeRepository repository;

  const RemoveCafeFromListUseCase(this.repository);

  Future<void> call(String listId, String cafeId) {
    return repository.removeCafeFromList(listId, cafeId);
  }
}
