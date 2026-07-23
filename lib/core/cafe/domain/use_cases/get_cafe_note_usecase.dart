import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class GetCafeNoteUseCase {
  final ICafeRepository repository;

  const GetCafeNoteUseCase(this.repository);

  Future<String?> call(String cafeId) {
    return repository.getCafeNote(cafeId);
  }
}
