import 'package:dartz/dartz.dart';
import 'package:nook/features/auth/domain/repository/auth_repository.dart';

class SignInWithAppleUsecase {
  final AuthRepository _repository;

  SignInWithAppleUsecase(this._repository);

  Future<Either<Failure, void>> call() async {
    return _repository.signInWithApple();
  }
}
