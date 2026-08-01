import 'package:nook/features/auth/domain/repository/auth_repository.dart';

class ResendSignupOtpUseCase {
  final AuthRepository _repository;

  ResendSignupOtpUseCase(this._repository);

  Future<void> call({required String email}) async {
    return _repository.resendSignupOtp(email: email);
  }
}
