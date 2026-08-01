import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Failure {
  final String message;

  const Failure(this.message);
}

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

  /// Confirms a pending signup with the code from the confirmation email.
  /// Establishes a session on success.
  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  });

  Future<void> resendSignupOtp({required String email});

  Future<void> signOut();

  Future<void> deleteAccount({String? password});

  Future<Either<Failure, void>> signInWithGoogle();

  Future<Either<Failure, void>> signInWithApple();

  Session? getCurrentSession();
}
