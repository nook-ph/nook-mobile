import 'package:nook/features/auth/data/datasources/supabase_auth_remote_data_source.dart';
import 'package:nook/features/auth/domain/repository/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  Future<bool> checkEmailExists(String email) async {
    try {
      return await _remoteDataSource.checkEmailExists(email);
    } on AuthException catch (e) {
      throw Exception(_mapAuthException(e));
    } catch (_) {
      throw Exception('Unable to check email right now. Please try again.');
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String fullName,
    required String password,
  }) async {
    try {
      await _remoteDataSource.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );
    } on AuthException catch (e) {
      throw Exception(_mapAuthException(e));
    } catch (_) {
      throw Exception(
        'Unable to create your account right now. Please try again.',
      );
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _remoteDataSource.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw Exception(_mapAuthException(e));
    } catch (_) {
      throw Exception('Unable to sign in right now. Please try again.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remoteDataSource.signOut();
    } on AuthException catch (e) {
      throw Exception(_mapAuthException(e));
    } catch (_) {
      throw Exception('Unable to sign out right now. Please try again.');
    }
  }

  @override
  Future<void> signInWithGoogle() {
    throw Exception('Google sign-in is not implemented yet.');
  }

  @override
  Future<void> signInWithApple() {
    throw Exception('Apple sign-in is not implemented yet.');
  }

  @override
  Future<void> signInWithFacebook() {
    throw Exception('Facebook sign-in is not implemented yet.');
  }

  String _mapAuthException(AuthException exception) {
    final message = exception.message.toLowerCase();

    if (message.contains('already registered') ||
        message.contains('user already registered')) {
      return 'An account with this email already exists.';
    }

    if (message.contains('invalid_credentials') ||
        message.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }

    if (message.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }

    return exception.message.isNotEmpty
        ? exception.message
        : 'Authentication failed. Please try again.';
  }
}
