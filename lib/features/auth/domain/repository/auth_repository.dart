abstract class AuthRepository {
  Future<bool> checkEmailExists(String email);

  Future<void> signUp({
    required String email,
    required String fullName,
    required String password,
  });

  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> signInWithFacebook();

  Future<void> signOut();
}
