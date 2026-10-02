class AppConstants {
  /// Custom URL scheme this build registers. The `dev` flavor ships a
  /// separate bundle id so it can sit beside the App Store build, and iOS
  /// picks arbitrarily between two apps claiming the same scheme — so the
  /// flavor overrides this via --dart-define and owns its own callbacks.
  static const String scheme = String.fromEnvironment(
    'DEEP_LINK_SCHEME',
    defaultValue: 'ph.nook.app',
  );

  /// Dev aid, off unless a build passes `--dart-define=FAKE_STAMPS=true`.
  /// A crawl stop then stamps on the device only, with no GPS fix and no
  /// server call, so the run, complete and share screens can be walked
  /// through from a desk. Nothing is written: real stamps still come only
  /// from the server's GPS check.
  static const bool fakeStamps = bool.fromEnvironment('FAKE_STAMPS');

  static const String loginHost = 'login-callback';
  static const String emailRedirectUri = '$scheme://$loginHost';
  static const String googleServerClientId =
      '190651012817-4l9qejfb0uhpr6jstk1hl2b6ish2gjfo.apps.googleusercontent.com';

  // Hosted legal documents (nook-ph/nook-privacy).
  static const String _legalBase = 'https://privacy.nookph.app';
  static const String eulaUrl = '$_legalBase/eula.html';
  static const String privacyPolicyUrl = '$_legalBase/index.html';

  // Bump when the terms change to force users to re-accept on next launch.
  static const String termsVersion = '1';
}
