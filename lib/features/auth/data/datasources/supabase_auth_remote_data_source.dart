import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRemoteDataSource {
  final SupabaseClient _client;
  bool _isGoogleInitialized = false;
  String? _googleServerClientId;

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

  Future<void> signInWithFacebook() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: 'nookapp://login-callback',
    );
  }

  Future<void> signInWithApple() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: 'nookapp://login-callback',
    );
  }

  Future<AuthResponse> signInWithGoogle(String webClientId) async {
    if (webClientId.isEmpty || webClientId.contains('YOUR_WEB_CLIENT_ID')) {
      throw const AuthException(
        'Google Sign-In is not configured. Set a real web client ID.',
      );
    }

    final googleSignIn = GoogleSignIn.instance;
    if (!_isGoogleInitialized || _googleServerClientId != webClientId) {
      await googleSignIn.initialize(serverClientId: webClientId);
      _isGoogleInitialized = true;
      _googleServerClientId = webClientId;
    }

    GoogleSignInAccount googleUser;
    try {
      googleUser = await googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthException('Google sign-in was canceled by the user.');
      }

      if (e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw AuthException(
          'Google Sign-In configuration error. Verify web client ID, Android package name, and SHA-1/SHA-256 fingerprints. ${e.description ?? ''}'
              .trim(),
        );
      }

      throw AuthException(
        'Google Sign-In failed (${e.code.name}). ${e.description ?? ''}'.trim(),
      );
    }

    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Missing Google ID token.');
    }

    final authorization = await googleUser.authorizationClient
        .authorizationForScopes(const <String>['email', 'profile']);

    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: authorization?.accessToken,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut(scope: SignOutScope.global);
  }
}
