import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRemoteDataSource {
  final SupabaseClient _client;

  SupabaseAuthRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<bool> checkEmailExists(String email) async {
    final result = await _client.rpc(
      'check_email_exists',
      params: {'check_email': email},
    );

    return result as bool;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String name,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
