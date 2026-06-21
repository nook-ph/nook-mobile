/// Holds the Google sign-in nonce shared between [main] bootstrap and
/// [SupabaseAuthRemoteDataSource.signInWithGoogle].
///
/// Per the Supabase / Google OIDC pattern:
///   * [nonce] is the **raw** nonce (32 random bytes, base64url-no-padding).
///   * `SHA-256(nonce)` (hex-encoded) is what is passed to
///     `GoogleSignIn.instance.initialize(nonce: ...)` — see [main].
///   * This raw value is what is passed verbatim to
///     `supabase.auth.signInWithIdToken(nonce: ...)`. Supabase computes the
///     same SHA-256 internally and compares with the `nonce` claim in the
///     Google ID token.
class GoogleAuthState {
  GoogleAuthState._();

  static String? nonce;
}
