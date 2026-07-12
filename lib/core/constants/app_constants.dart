class AppConstants {
  static const String emailRedirectUri = 'ph.nook.app://login-callback';
  static const String scheme = 'ph.nook.app';
  static const String loginHost = 'login-callback';
  static const String googleServerClientId =
      '190651012817-4l9qejfb0uhpr6jstk1hl2b6ish2gjfo.apps.googleusercontent.com';

  // Hosted legal documents (nook-ph/nook-privacy).
  static const String _legalBase = 'https://privacy.nookph.app';
  static const String eulaUrl = '$_legalBase/eula.html';
  static const String privacyPolicyUrl = '$_legalBase/index.html';

  // Bump when the terms change to force users to re-accept on next launch.
  static const String termsVersion = '1';
}
