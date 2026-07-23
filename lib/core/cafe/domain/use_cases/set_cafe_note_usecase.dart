import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

class SetCafeNoteUseCase {
  final ICafeRepository repository;

  const SetCafeNoteUseCase(this.repository);

  Future<String?> call(String cafeId, String? note) {
    return repository.setCafeNote(cafeId, note);
  }
}
