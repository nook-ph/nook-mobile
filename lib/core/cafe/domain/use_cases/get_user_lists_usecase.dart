import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
class GetUserListsUseCase {
  final ICafeRepository repository;

  const GetUserListsUseCase(this.repository);

  Future<List<CafeList>> call() {
    return repository.getUserLists();
  }
}