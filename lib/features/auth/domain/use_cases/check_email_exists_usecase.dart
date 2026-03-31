import 'package:nook/features/auth/domain/repository/auth_repository.dart';

class CheckEmailExistsUsecase {
  final AuthRepository repository;

  CheckEmailExistsUsecase(this.repository);

  Future<bool> call(String email) async {
    if (email.isEmpty || !email.contains('@')) {
      throw Exception('Invalid email format');
    }

    return await repository.checkEmailExists(email);
  }
}
