import 'package:dartz/dartz.dart';
import 'package:nook/features/auth/data/datasources/supabase_auth_remote_data_source.dart';
import 'package:nook/features/auth/domain/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<bool> emailExists(String email) async {
    return _remoteDataSource.checkEmailExists(email);
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String name,
    required String password,
  }) async {
    return await _remoteDataSource.signUp(
      email: email,
      name: name,
      password: password,
    );
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    return _remoteDataSource.verifySignupOtp(email: email, token: token);
  }

  @override
  Future<void> resendSignupOtp({required String email}) async {
    return _remoteDataSource.resendSignupOtp(email: email);
  }

  @override
  Future<void> signOut() async {
    await _remoteDataSource.signOut();
  }

  @override
  Future<void> deleteAccount({String? password}) async {
    if (password != null && password.isNotEmpty) {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final email = currentUser?.email;
      if (email == null || email.isEmpty) {
        throw const AuthException('No email associated with the current user.');
      }
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } on AuthException {
        rethrow;
      } catch (_) {
        throw const AuthException('Invalid password.');
      }
    }
    await _remoteDataSource.deleteAccount();
  }

  @override
  Future<Either<Failure, void>> signInWithApple() async {
    try {
      await _remoteDataSource.signInWithApple();
      return const Right<Failure, void>(null);
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> signInWithGoogle() async {
    try {
      await _remoteDataSource.signInWithGoogle();
      return const Right<Failure, void>(null);
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }

  @override
  Session? getCurrentSession() {
    return Supabase.instance.client.auth.currentSession;
  }
}
