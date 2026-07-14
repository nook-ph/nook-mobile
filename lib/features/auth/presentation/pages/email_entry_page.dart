import 'dart:io' show Platform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nook/core/constants/app_constants.dart';
import 'package:nook/core/preferences/terms_acceptance_store.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/injection_container.dart';

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
  bool _showTermsError = false;
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
      if (_emailError != null) {
        final text = _emailController.text.trim();
        if (_isValidEmail(text) || text.isEmpty) {
          setState(() => _emailError = null);
        }
      } else {
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrefillFromExtra) return;

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

  /// Gate every sign-in path behind terms acceptance. Instead of silently
  /// disabling the buttons (which leaves users guessing why nothing happens),
  /// the buttons stay tappable and this surfaces a toast + highlights the
  /// checkbox when the box is still unchecked.
  bool _ensureTermsAgreed() {
    if (_agreedToTerms) return true;
    setState(() => _showTermsError = true);
    showPrimaryToast(
      context,
      'Please agree to the Terms of Use and Privacy Policy to continue.',
    );
    return false;
  }

  Future<void> _openLegal(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showPrimaryToast(context, 'Could not open the page. Please try again.');
      }
    }
  }

  void _onContinuePressed(BuildContext context) {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _emailError = 'This email is invalid');
      return;
    }
    setState(() => _emailError = null);
    if (!_ensureTermsAgreed()) return;
    _persistTermsAcceptance();
    context.read<AuthBloc>().add(AuthCheckEmailEvent(email));
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required String text,
    required Widget icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: AdaptiveOutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          foregroundColor: Colors.black87,
          side: BorderSide(color: context.colorScheme.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              text,
              style: context.textTheme.bodyLargeSemi.copyWith(
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Required agreement gate: users must accept the Terms of Use (EULA) and
  /// Privacy Policy — which state nook - Cafe Finder's zero-tolerance policy for
  /// objectionable content and abusive users — before logging in or signing up.
  Widget _buildTermsAgreement(BuildContext context) {
    final linkStyle = context.textTheme.bodySmall!.copyWith(
      color: const Color(0xFF344E41),
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );
    final baseStyle = context.textTheme.bodySmall!.copyWith(
      color: const Color(0xFF848685),
    );

    void toggle(bool value) => setState(() {
      _agreedToTerms = value;
      if (value) _showTermsError = false;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _agreedToTerms,
                activeColor: const Color(0xFF344E41),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: _showTermsError
                    ? const BorderSide(color: Colors.red, width: 2)
                    : null,
                onChanged: (value) => toggle(value ?? false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => toggle(!_agreedToTerms),
                child: Text.rich(
                  TextSpan(
                    style: baseStyle,
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      TextSpan(
                        text: 'Terms of Use (EULA)',
                        style: linkStyle,
                        recognizer: _eulaTap,
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: linkStyle,
                        recognizer: _privacyTap,
                      ),
                      const TextSpan(
                        text:
                            '. nook - Cafe Finder has zero tolerance for '
                            'objectionable content and abusive behavior.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_showTermsError) ...[
          const Gap(6),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              'Please check this box to continue.',
              style: context.textTheme.bodySmall!.copyWith(color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthEmailChecked) {
          if (state.exists) {
            context.go('/login-password', extra: state.email);
          } else {
            context.go('/signup-details', extra: state.email);
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
          context.go('/');
          return;
        }
        if (state is AuthError) {
          showPrimaryToast(context, state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final email = _emailController.text.trim();
        // Terms acceptance is enforced at tap time (via _ensureTermsAgreed)
        // rather than by disabling the button, so users get clear feedback.
        final canSubmit = email.isNotEmpty && !isLoading;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: AdaptiveTap(
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back),
              ),
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    const Gap(60),
                    Column(
                      children: [
                        Image.asset('assets/logos/logoT.png', width: 110),
                        const Gap(22),
                        Text(
                          'Log in or Sign up',
                          style: context.textTheme.titleLargeSemi,
                        ),
                      ],
                    ),
                    const Gap(24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Email Address',
                        hintStyle: context.textTheme.bodySmall!.copyWith(
                          color: const Color(0xFFA8AAAA),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black87),
                        ),
                      ),
                    ),
                    if (_emailError != null) ...[
                      const Gap(8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _emailError!,
                          style: context.textTheme.bodySmall!.copyWith(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                    const Gap(16),
                    SizedBox(
                      width: double.infinity,
                      child: AdaptiveElevatedButton(
                        onPressed: canSubmit
                            ? () => _onContinuePressed(context)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF344E41),
                          disabledBackgroundColor: const Color(
                            0xFF344E41,
                          ).withOpacity(0.5),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white.withOpacity(
                            0.8,
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Continue',
                                style: context.textTheme.bodyLargeMed.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const Gap(24),
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFE0E0E0),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'OR',
                            style: context.textTheme.bodyLargeMed.copyWith(
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFE0E0E0),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const Gap(24),
                    _buildSocialButton(
                      context: context,
                      text: 'Continue with Google',
                      icon: Image.asset(
                        'assets/logos/googleLogo.png',
                        height: 20,
                        width: 20,
                      ),
                      onPressed: isLoading
                          ? null
                          : () {
                              if (!_ensureTermsAgreed()) return;
                              _persistTermsAcceptance();
                              context.read<AuthBloc>().add(
                                const AuthSignInWithGoogleEvent(),
                              );
                            },
                    ),
                    if (Platform.isIOS) ...[
                      const SizedBox(height: 12),
                      _buildSocialButton(
                        context: context,
                        text: 'Continue with Apple',
                        icon: const Icon(
                          Icons.apple,
                          color: Colors.black,
                          size: 28,
                        ),
                        onPressed: isLoading
                            ? null
                            : () {
                                if (!_ensureTermsAgreed()) return;
                                _persistTermsAcceptance();
                                context.read<AuthBloc>().add(
                                  const AuthSignInWithAppleEvent(),
                                );
                              },
                      ),
                    ],
                    const Gap(20),
                    _buildTermsAgreement(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
