import 'package:nook/features/auth/domain/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpWithEmailUseCase {
  final AuthRepository _repository;

  SignUpWithEmailUseCase(this._repository);

  Future<AuthResponse> call({
    required String email,
    required String name,
    required String password,
  }) async {
    return _repository.signUp(email: email, name: name, password: password);
  }
}
