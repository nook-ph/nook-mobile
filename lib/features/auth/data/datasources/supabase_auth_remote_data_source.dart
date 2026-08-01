import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nook/core/auth/google_auth_state.dart';
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
      data: {
        'full_name': name,
        // Switches the shared "Confirm signup" template
        // (nook-supabase/supabase/templates/confirmation.html) to its
        // `{{ if .Data.otp_signup }}` branch, which renders {{ .Token }}.
        // Without this flag the email is link-only and there is no code to type.
        'otp_signup': true,
      },
      emailRedirectTo: AppConstants.emailRedirectUri,
    );
  }

  /// Confirms a new account with the code from the signup email.
  ///
  /// On success this establishes a session, exactly like signInWithPassword —
  /// the caller is responsible for the post-login gate.
  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    developer.log('Verifying signup OTP: email=$email', name: 'EmailVerification');
    return await _client.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: token,
    );
  }

  /// Re-sends the signup confirmation email. [emailRedirectTo] is kept so the
  /// tap-the-link path in the same email keeps working as a fallback.
  Future<void> resendSignupOtp({required String email}) async {
    developer.log('Resending signup OTP: email=$email', name: 'EmailVerification');
    await _client.auth.resend(
      type: OtpType.signup,
      email: email,
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

  Future<void> signInWithGoogle() async {
    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate(
        scopeHint: const ['email', 'profile', 'openid'],
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('CANCELED');
      }
      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw AuthException(
          'Google Sign-In configuration error. Verify the server client ID and platform configuration.',
        );
      }
      throw AuthException('Google Sign-In failed (${e.code.name}).');
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Google Sign-In did not return an ID token.');
    }

    final rawNonce = GoogleAuthState.nonce;
    final expectedDigest = rawNonce == null
        ? null
        : sha256.convert(utf8.encode(rawNonce)).toString();
    final idTokenNonce = _idTokenNonce(idToken);
    debugPrint(
      'GoogleAuth: idToken nonce claim[0..8]='
      '${(idTokenNonce ?? '<null>').toString().substring(0, (idTokenNonce ?? '<null>').toString().length.clamp(0, 8))}… '
      'expected SHA256(rawNonce)[0..8]='
      '${(expectedDigest ?? '<null>').toString().substring(0, (expectedDigest ?? '<null>').toString().length.clamp(0, 8))}… '
      'match=${idTokenNonce != null && idTokenNonce == expectedDigest}',
    );

    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  String? _idTokenNonce(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      final padding = (4 - payload.length % 4) % 4;
      payload = payload + ('=' * padding);
      final decoded = utf8.decode(base64Decode(payload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return json['nonce'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut(scope: SignOutScope.global);
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // GoogleSignIn may not be initialized if the user never signed in with Google.
    }
  }

  Future<void> deleteAccount() async {
    final response = await _client.functions.invoke(
      'delete-user',
      method: HttpMethod.post,
    );
    if (response.status != 200) {
      throw AuthException('Account deletion failed. Please try again later.');
    }
  }
}
