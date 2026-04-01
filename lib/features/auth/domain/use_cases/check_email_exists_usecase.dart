import 'package:nook/features/auth/domain/repository/auth_repository.dart';

class CheckEmailExistsUseCase {
  final AuthRepository _repository;

  CheckEmailExistsUseCase(this._repository);

  Future<bool> call(String email) async {
    return _repository.emailExists(email);
  }
}
