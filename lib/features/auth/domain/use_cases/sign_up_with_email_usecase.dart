import 'package:nook/features/auth/domain/repository/auth_repository.dart';

class SignUpWithEmailUsecase {
  final AuthRepository repository;

  SignUpWithEmailUsecase(this.repository);

  Future<void> call({
    required String email,
    required String fullName,
    required String password,
  }) async {
    if (password.length < 8) {
      throw Exception('Password must contain at least 8 characters');
    }

    return await repository.signUp(
      email: email,
      fullName: fullName,
      password: password,
    );
  }
}
