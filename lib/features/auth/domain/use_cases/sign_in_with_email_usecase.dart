import 'package:nook/features/auth/domain/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignInWithEmailUseCase {
  final AuthRepository _repository;

  SignInWithEmailUseCase(this._repository);

  Future<AuthResponse> call({
    required String email,
    required String password,
  }) async {
    return _repository.signIn(email: email, password: password);
  }
}
