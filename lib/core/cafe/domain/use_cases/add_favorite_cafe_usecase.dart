import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class AddFavoriteCafeUseCase {
  final ICafeRepository repository;

  AddFavoriteCafeUseCase(this.repository);

  Future<void> call(String cafeId, {String? userId}) {
    return repository.addFavoriteCafe(cafeId, userId: userId);
  }
}
