import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/auth/auth_return.dart';
import 'package:nook/core/constants/app_constants.dart';
import 'package:nook/core/preferences/terms_acceptance_store.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';
import 'package:nook/injection_container.dart';
import 'package:url_launcher/url_launcher.dart';

/// Which action put the page into [AuthLoading], so only that control spins
/// (B4 "Checking…" on Continue, B9 the provider's own button).
enum _Pending { email, google, apple }

/// "Log in or sign up" (Figma B1–B5, B9, F10).
class EmailEntryScreen extends StatefulWidget {
  const EmailEntryScreen({super.key});

  @override
  State<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends State<EmailEntryScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TermsAcceptanceStore _termsStore = sl<TermsAcceptanceStore>();
  String? _emailError;
  bool _didPrefillFromExtra = false;
  bool _agreedToTerms = false;
  _Pending? _pending;
  late final TapGestureRecognizer _eulaTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _eulaTap = TapGestureRecognizer()
      ..onTap = () => _openLegal(AppConstants.eulaUrl);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _openLegal(AppConstants.privacyPolicyUrl);
    _loadTermsAcceptance();
    _emailController.addListener(() {
      setState(() {
        if (_emailError != null) {
          final text = _emailController.text.trim();
          if (isValidAuthEmail(text) || text.isEmpty) _emailError = null;
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrefillFromExtra) return;

    // The page under this screen is where sign-in should return to.
    AuthReturn.rememberOrigin(GoRouter.of(context));

    final email = GoRouterState.of(context).extra as String?;
    if (email != null && email.trim().isNotEmpty) {
      _emailController.text = email.trim();
    }
    _didPrefillFromExtra = true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _eulaTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _loadTermsAcceptance() async {
    final accepted = await _termsStore.hasAccepted(AppConstants.termsVersion);
    if (mounted && accepted) {
      setState(() => _agreedToTerms = true);
    }
  }

  /// Records terms acceptance the first time a user proceeds past this screen.
  void _persistTermsAcceptance() {
    _termsStore.markAccepted(AppConstants.termsVersion);
  }

  Future<void> _openLegal(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showAuthToast(context, 'Could not open the page. Please try again.');
      }
    }
  }

  void _onContinuePressed() {
    final email = _emailController.text.trim();
    if (!isValidAuthEmail(email)) {
      setState(() => _emailError = 'This email is invalid');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _emailError = null;
      _pending = _Pending.email;
    });
    _persistTermsAcceptance();
    context.read<AuthBloc>().add(AuthCheckEmailEvent(email));
  }

  void _signInWith(_Pending provider) {
    setState(() => _pending = provider);
    _persistTermsAcceptance();
    context.read<AuthBloc>().add(
      provider == _Pending.apple
          ? const AuthSignInWithAppleEvent()
          : const AuthSignInWithGoogleEvent(),
    );
  }

  void _onBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is! AuthLoading) setState(() => _pending = null);
        if (state is AuthEmailChecked) {
          // Pushed, not `go`: `go` replaced the whole stack, so the system
          // Back button on the next screen closed the app (docs/ux/signup.md,
          // finding 1). Pushed, Back returns here with the email still typed.
          if (state.exists) {
            context.push('/login-password', extra: state.email);
          } else {
            context.push('/signup-details', extra: state.email);
          }
          return;
        }
        if (state is AuthAwaitingEmailConfirmation) {
          context.go('/email-confirmation');
          return;
        }
        if (state is AuthNeedsUsername) {
          context.go(
            '/username-setup',
            extra: {'fullName': state.fullName, 'avatarUrl': state.avatarUrl},
          );
          return;
        }
        if (state is AuthAuthenticated) {
          finishSignIn(context);
          return;
        }
        if (state is AuthError) {
          showAuthToast(context, state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final pending = isLoading ? _pending : null;
        final email = _emailController.text.trim();
        final canSubmit =
            email.isNotEmpty &&
            !isLoading &&
            _agreedToTerms &&
            _emailError == null;
        final providersEnabled = !isLoading && _agreedToTerms;
        final error = _emailError;

        return AuthPage(
          onBack: _onBack,
          topPadding: 28,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                // The design's 4 spacer and the second 16 gap it brings.
                padding: const EdgeInsets.only(bottom: 20),
                child: Image.asset(
                  'assets/logos/logoT.png',
                  width: 110,
                  height: 37,
                  cacheWidth: (110 * MediaQuery.devicePixelRatioOf(context))
                      .ceil(),
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            const Text('Log in or sign up', style: AuthText.title),
            AuthTextField(
              controller: _emailController,
              label: 'Email',
              hintText: 'Email address',
              errorText: error,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.email],
              enabled: !isLoading,
              onSubmitted: (_) {
                if (canSubmit) _onContinuePressed();
              },
              trailing: error != null
                  ? const Icon(
                      LucideIcons.circleAlert,
                      size: 18,
                      color: AuthColors.danger,
                    )
                  : email.isEmpty
                  ? null
                  : AuthClearButton(
                      onTap: isLoading ? () {} : _emailController.clear,
                    ),
            ),
            AuthTermsAgreement(
              value: _agreedToTerms,
              onChanged: (value) => setState(() => _agreedToTerms = value),
              eulaRecognizer: _eulaTap,
              privacyRecognizer: _privacyTap,
            ),
            AuthPrimaryButton(
              label: 'Continue',
              loading: pending == _Pending.email,
              loadingLabel: 'Checking…',
              onPressed: canSubmit ? _onContinuePressed : null,
            ),
            const AuthOrDivider(),
            AuthOutlineButton(
              label: 'Continue with Google',
              icon: Image.asset(
                'assets/logos/googleLogo.png',
                width: 18,
                height: 18,
                cacheWidth: (18 * MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
              ),
              loading: pending == _Pending.google,
              onPressed: providersEnabled
                  ? () => _signInWith(_Pending.google)
                  : null,
            ),
            if (Platform.isIOS)
              AuthOutlineButton(
                label: 'Continue with Apple',
                icon: const Icon(
                  LucideIcons.apple,
                  size: 18,
                  color: AuthColors.ink,
                ),
                loading: pending == _Pending.apple,
                onPressed: providersEnabled
                    ? () => _signInWith(_Pending.apple)
                    : null,
              ),
          ],
        );
      },
    );
  }
}
