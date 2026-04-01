import 'package:supabase_flutter/supabase_flutter.dart';

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

  Session? getCurrentSession();
}
