import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class AddCafeToListUseCase {
  final ICafeRepository repository;

  const AddCafeToListUseCase(this.repository);

  Future<void> call(String listId, String cafeId) {
    return repository.addCafeToList(listId, cafeId);
  }
}
