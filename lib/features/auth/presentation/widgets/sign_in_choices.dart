import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/constants/app_constants.dart';
import 'package:nook/core/preferences/terms_acceptance_store.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';
import 'package:nook/injection_container.dart';
import 'package:url_launcher/url_launcher.dart';

/// How a guest chose to sign in from a sheet.
enum SignInChoice { google, apple, email }

/// Sign in with Apple is offered on iOS only, as it always has been.
bool get showAppleSignIn =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// A Google or Apple button: an ink pill with the provider's mark, the
/// primary way in wherever sign-in is offered. Email sits under it as the
/// secondary option.
class AuthProviderButton extends StatelessWidget {
  const AuthProviderButton({
    super.key,
    required this.provider,
    required this.onPressed,
    this.loading = false,
    this.height = 52,
    this.agreeFirst = false,
  }) : assert(provider != SignInChoice.email);

  final SignInChoice provider;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;

  /// The terms were shown because the box was not ticked: the button then
  /// says that tapping it agrees ("Agree and continue with Google").
  final bool agreeFirst;

  static const googleLabel = 'Continue with Google';
  static const appleLabel = 'Continue with Apple';
  static const agreeGoogleLabel = 'Agree and continue with Google';
  static const agreeAppleLabel = 'Agree and continue with Apple';

  String get label => provider == SignInChoice.apple
      ? (agreeFirst ? agreeAppleLabel : appleLabel)
      : (agreeFirst ? agreeGoogleLabel : googleLabel);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final Widget mark = provider == SignInChoice.apple
        ? const Icon(LucideIcons.apple, size: 18, color: AuthColors.surface)
        : Image.asset(
            'assets/logos/googleLogo.png',
            width: 18,
            height: 18,
            cacheWidth: (18 * MediaQuery.devicePixelRatioOf(context)).ceil(),
          );
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled || loading ? 1 : 0.4,
        child: AdaptiveTap(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AuthColors.ink,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (loading)
                  const AuthSpinner(color: AuthColors.surface)
                else
                  mark,
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AuthText.button,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The sign-in buttons of a guest sheet: Apple (iOS) and Google first, then
/// "Continue with email". A provider signs in from the sheet itself, so a
/// guest who tapped Save is two taps from done instead of a whole flow.
///
/// Google and Apple need the terms agreed first, as on the login page. Once
/// agreed on this device the box is not shown again. A provider tapped with
/// the box unticked opens the terms inline, and its button becomes "Agree
/// and continue with ...": one more tap, never a red error. The agreement
/// stays an explicit act (the tick or that button), which App Review asks
/// of apps with user content (guideline 1.2 rejections: "Require that users
/// agree to terms (EULA)"); a passive "By continuing..." line has been
/// rejected on its own.
class SheetSignInChoices extends StatefulWidget {
  const SheetSignInChoices({
    super.key,
    required this.onChoice,
    this.buttonHeight = 48,
    this.termsStore,
  });

  final ValueChanged<SignInChoice> onChoice;
  final double buttonHeight;

  /// Defaults to the app's store.
  final TermsAcceptanceStore? termsStore;

  static const emailLabel = 'Continue with email';

  @override
  State<SheetSignInChoices> createState() => _SheetSignInChoicesState();
}

class _SheetSignInChoicesState extends State<SheetSignInChoices> {
  late final TermsAcceptanceStore? _store =
      widget.termsStore ??
      (sl.isRegistered<TermsAcceptanceStore>()
          ? sl<TermsAcceptanceStore>()
          : null);

  /// Null until the store answers, so someone who agreed before does not
  /// see the box flash up.
  bool? _alreadyAgreed;
  bool _agreed = false;

  /// The provider tapped with the box unticked: the terms are open inline
  /// and its button agrees and continues.
  SignInChoice? _confirming;
  late final TapGestureRecognizer _eulaTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(AppConstants.eulaUrl);
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = () => _openLegal(AppConstants.privacyPolicyUrl);

  @override
  void initState() {
    super.initState();
    _loadAgreement();
  }

  @override
  void dispose() {
    _eulaTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _loadAgreement() async {
    var accepted = false;
    try {
      accepted = await _store?.hasAccepted(AppConstants.termsVersion) ?? false;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _alreadyAgreed = accepted;
      _agreed = accepted;
    });
  }

  Future<void> _openLegal(String url) async {
    if (!await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    )) {
      if (mounted) {
        showAuthToast(context, 'Could not open the page. Please try again.');
      }
    }
  }

  void _provider(SignInChoice choice) {
    if (!_agreed && _confirming != choice) {
      setState(() => _confirming = choice);
      return;
    }
    if (_alreadyAgreed != true) {
      _store?.markAccepted(AppConstants.termsVersion).catchError((_) {});
    }
    widget.onChoice(choice);
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 8);
    final showTerms = _alreadyAgreed == false;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTerms) ...[
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _confirming != null && !_agreed
                ? _InlineTerms(
                    eulaRecognizer: _eulaTap,
                    privacyRecognizer: _privacyTap,
                  )
                : AuthTermsAgreement(
                    value: _agreed,
                    onChanged: (value) => setState(() => _agreed = value),
                    eulaRecognizer: _eulaTap,
                    privacyRecognizer: _privacyTap,
                  ),
          ),
          const SizedBox(height: 12),
        ],
        if (showAppleSignIn) ...[
          AuthProviderButton(
            provider: SignInChoice.apple,
            height: widget.buttonHeight,
            agreeFirst: !_agreed && _confirming == SignInChoice.apple,
            onPressed: () => _provider(SignInChoice.apple),
          ),
          gap,
        ],
        AuthProviderButton(
          provider: SignInChoice.google,
          height: widget.buttonHeight,
          agreeFirst: !_agreed && _confirming == SignInChoice.google,
          onPressed: () => _provider(SignInChoice.google),
        ),
        gap,
        Semantics(
          button: true,
          child: AdaptiveTap(
            onTap: () => widget.onChoice(SignInChoice.email),
            borderRadius: BorderRadius.circular(100),
            child: Container(
              constraints: BoxConstraints(minHeight: widget.buttonHeight),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AuthColors.border),
              ),
              child: Text(
                SheetSignInChoices.emailLabel,
                textAlign: TextAlign.center,
                style: AuthText.button.copyWith(color: AuthColors.ink),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The terms, opened in the sheet when a provider was tapped before the box
/// was ticked. Says what agreeing means; the provider button under it is the
/// "I agree".
class _InlineTerms extends StatelessWidget {
  const _InlineTerms({
    required this.eulaRecognizer,
    required this.privacyRecognizer,
  });

  final GestureRecognizer eulaRecognizer;
  final GestureRecognizer privacyRecognizer;

  static const title = 'Before you continue';

  @override
  Widget build(BuildContext context) {
    final link = AuthText.small.copyWith(
      color: AuthColors.brand,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: AuthColors.brand,
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AuthColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AuthText.small.copyWith(
                color: AuthColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                style: AuthText.small,
                children: [
                  const TextSpan(text: 'Your account follows the '),
                  TextSpan(
                    text: 'Terms of Use (EULA)',
                    style: link,
                    recognizer: eulaRecognizer,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: link,
                    recognizer: privacyRecognizer,
                  ),
                  const TextSpan(
                    text:
                        '. Nook has zero tolerance for objectionable content '
                        'and abusive behavior.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
