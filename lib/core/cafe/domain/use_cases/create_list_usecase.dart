import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class CreateListUseCase {
  final ICafeRepository repository;

  const CreateListUseCase(this.repository);

  Future<String> call({required String name, String? description, required bool isPublic}) {
    if (name.trim().isEmpty) {
      throw ArgumentError('List name cannot be empty.');
    }
    return repository.createList(name: name.trim(), description: description, isPublic: isPublic);
  }
}