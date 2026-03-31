import 'package:nook/features/auth/domain/repository/auth_repository.dart';

class SignInWithEmailUsecase {
  final AuthRepository repository;

  SignInWithEmailUsecase(this.repository);

  Future<void> call({
    required String email,
    required String password,
  }) async {
    
    if (password.trim().isEmpty) {
      throw Exception('Password cannot be empty');
    }
    
    return await repository.signInWithEmail(
      email: email,
      password: password,
    );
  }
}