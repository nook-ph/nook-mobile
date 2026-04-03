import 'package:dartz/dartz.dart';
import 'package:nook/features/auth/domain/repository/auth_repository.dart';

class SignInWithFacebook {
  final AuthRepository _repository;

  SignInWithFacebook(this._repository);

  Future<Either<Failure, void>> call() async {
    return _repository.signInWithFacebook();
  }
}
