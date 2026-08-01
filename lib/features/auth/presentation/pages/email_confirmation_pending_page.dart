import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';

class EmailConfirmationPendingScreen extends StatefulWidget {
  const EmailConfirmationPendingScreen({super.key});

  @override
  State<EmailConfirmationPendingScreen> createState() =>
      _EmailConfirmationPendingScreenState();
}

class _EmailConfirmationPendingScreenState
    extends State<EmailConfirmationPendingScreen> {
  static const _cooldownDuration = Duration(seconds: 60);

  /// Supabase allows 6–10 digit OTPs and the length is a project-wide setting
  /// (`mailer_otp_length`), so the screen accepts the whole range instead of
  /// pinning to today's value — changing it in the dashboard must not ship a
  /// client that rejects the codes it now sends.
  static const _minCodeLength = 6;
  static const _maxCodeLength = 10;

  final TextEditingController _codeController = TextEditingController();
  Timer? _cooldownTimer;
  int _secondsLeft = 0;
  int _lastHandledResend = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _secondsLeft = _cooldownDuration.inSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  void _verify() {
    final code = _codeController.text.trim();
    if (code.length < _minCodeLength) return;
    FocusManager.instance.primaryFocus?.unfocus();
    context.read<AuthBloc>().add(AuthVerifyOtpEvent(code));
  }

  void _resend() {
    if (_secondsLeft > 0) return;
    context.read<AuthBloc>().add(const AuthResendOtpEvent());
  }

  void _goBackToSignup(String email) {
    context.read<AuthBloc>().add(const AuthSessionCheckEvent());
    context.go('/login', extra: email);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (prev, curr) => curr is AuthAwaitingEmailConfirmation,
      listener: (context, state) {
        if (state is! AuthAwaitingEmailConfirmation) return;
        // Start the cooldown off the bloc's counter rather than off the tap, so
        // it only runs when the email actually went out.
        if (state.resendCount > _lastHandledResend) {
          _lastHandledResend = state.resendCount;
          _startCooldown();
        }
      },
      buildWhen: (prev, curr) => curr is AuthAwaitingEmailConfirmation,
      builder: (context, state) {
        // buildWhen keeps the last pending state around while the router is
        // still tearing this route down after a successful verify, so this only
        // guards the window before the redirect lands.
        if (state is! AuthAwaitingEmailConfirmation) {
          return const Scaffold(backgroundColor: Colors.white);
        }
        final pending = state;
        final email = pending.email.trim();
        final canResend = !pending.isResending && _secondsLeft == 0;

        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Gap(50),
                    Image.asset('assets/logos/logoT.png', width: 110),
                    const Gap(24),
                    Text(
                      'Enter your code',
                      style: context.textTheme.titleLargeSemi,
                    ),
                    const Gap(8),
                    Text(
                      'We sent a verification code to $email',
                      style: context.textTheme.bodySmall!.copyWith(
                        color: const Color(0xFFA8AAAA),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(28),
                    _CodeField(
                      controller: _codeController,
                      enabled: !pending.isVerifying,
                      maxLength: _maxCodeLength,
                      hasError: pending.error != null,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _verify(),
                    ),
                    if (pending.error != null) ...[
                      const Gap(10),
                      Text(
                        pending.error!,
                        style: context.textTheme.bodySmall!.copyWith(
                          color: const Color(0xFFD64545),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const Gap(24),
                    SizedBox(
                      width: double.infinity,
                      child: AdaptiveElevatedButton(
                        onPressed:
                            pending.isVerifying ||
                                _codeController.text.trim().length <
                                    _minCodeLength
                            ? null
                            : _verify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF344E41),
                          disabledBackgroundColor: const Color(
                            0xFF344E41,
                          ).withValues(alpha: 0.5),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white.withValues(
                            alpha: 0.8,
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: pending.isVerifying
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
                                'Verify & continue',
                                style: context.textTheme.bodyLargeMed.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const Gap(16),
                    AdaptiveTextButton(
                      onPressed: canResend ? _resend : null,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: pending.isResending
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF344E41),
                                ),
                              ),
                            )
                          : Text(
                              _secondsLeft > 0
                                  ? 'Resend code in ${_secondsLeft}s'
                                  : "Didn't get a code? Resend",
                              style: context.textTheme.bodyLargeMed.copyWith(
                                color: _secondsLeft > 0
                                    ? const Color(0xFFA8AAAA)
                                    : const Color(0xFF344E41),
                              ),
                            ),
                    ),
                    const Gap(20),
                    Text(
                      'The same email also has a confirmation link if you would '
                      'rather tap that.',
                      style: context.textTheme.bodySmall!.copyWith(
                        color: const Color(0xFFA8AAAA),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(20),
                    AdaptiveTextButton(
                      onPressed: email.isEmpty
                          ? null
                          : () => _goBackToSignup(email),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Wrong email? Go back',
                        style: context.textTheme.bodyLargeMed.copyWith(
                          color: const Color(0xFF344E41),
                        ),
                      ),
                    ),
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

class _CodeField extends StatelessWidget {
  const _CodeField({
    required this.controller,
    required this.enabled,
    required this.maxLength,
    required this.hasError,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final int maxLength;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? const Color(0xFFD64545)
        : const Color(0xFF344E41).withValues(alpha: 0.2);

    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: true,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      // Lets Android and iOS offer the code straight from the notification
      // instead of making the user switch to their mail app and memorise it.
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(maxLength),
      ],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: context.textTheme.titleLargeSemi.copyWith(
        letterSpacing: 8,
        color: Colors.black,
      ),
      decoration: InputDecoration(
        hintText: 'Enter code',
        hintStyle: context.textTheme.bodyLargeMed.copyWith(
          letterSpacing: 0,
          color: const Color(0xFFA8AAAA),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: hasError
                ? const Color(0xFFD64545)
                : const Color(0xFF344E41),
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
    );
  }
}
