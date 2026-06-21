import 'dart:developer' as developer;

import 'package:nook/core/constants/app_constants.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRemoteDataSource {
  final SupabaseClient _client;

  SupabaseAuthRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<bool> checkEmailExists(String email) async {
    developer.log(
      'Checking email existence: $email',
      name: 'EmailVerification',
    );
    final result = await _client.rpc(
      'check_email_exists',
      params: {'check_email': email},
    );
    final exists = result as bool;
    developer.log('Email existence result: $exists', name: 'EmailVerification');
    return exists;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String name,
    required String password,
  }) async {
    developer.log(
      'Signing up user: email=$email, redirect=${AppConstants.emailRedirectUri}',
      name: 'EmailVerification',
    );
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
      emailRedirectTo: AppConstants.emailRedirectUri,
    );
  }

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithApple() async {
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthException('CANCELED');
      }
      throw AuthException('Apple Sign-In failed: ${e.message}');
    } on SignInWithAppleNotSupportedException catch (_) {
      throw const AuthException(
        'Apple Sign-In is not supported on this device.',
      );
    }

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException(
        'Apple Sign-In did not return an identity token.',
      );
    }

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
    );
  }

  Future<bool> signInWithGoogle() async {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'ph.nook.app://login-callback',
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut(scope: SignOutScope.global);
  }
}
