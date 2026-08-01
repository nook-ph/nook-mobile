import 'package:nook/features/auth/domain/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VerifySignupOtpUseCase {
  final AuthRepository _repository;

  VerifySignupOtpUseCase(this._repository);

  Future<AuthResponse> call({
    required String email,
    required String token,
  }) async {
    return _repository.verifySignupOtp(email: email, token: token);
  }
}
