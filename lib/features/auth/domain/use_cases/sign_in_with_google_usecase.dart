import 'package:dartz/dartz.dart';
import 'package:nook/features/auth/domain/repository/auth_repository.dart';

class SignInWithGoogleUseCase {
  final AuthRepository _repository;

  SignInWithGoogleUseCase(this._repository);

  Future<Either<Failure, void>> call(String webClientId) async {
    return _repository.signInWithGoogle(webClientId);
  }
}
