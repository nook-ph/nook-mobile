import 'package:dartz/dartz.dart';
import 'package:nook/core/errors/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:nook/core/errors/failure.dart';

abstract class AuthRepository {
  Future<bool> emailExists(String email);

  Future<AuthResponse> signUp({
    required String email,
    required String name,
    required String password,
  });

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<Either<Failure, void>> signInWithGoogle(String webClientId);

  Future<Either<Failure, void>> signInWithApple();

  Session? getCurrentSession();
}
