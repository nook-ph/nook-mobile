import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class RemoveFavoriteCafeUseCase {
  final ICafeRepository repository;

  RemoveFavoriteCafeUseCase(this.repository);

  Future<void> call(String cafeId, {String? userId}) {
    return repository.removeFavoriteCafe(cafeId, userId: userId);
  }
}
