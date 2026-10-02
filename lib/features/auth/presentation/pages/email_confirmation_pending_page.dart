import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/widgets/auth_code_boxes.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';

class EmailConfirmationPendingScreen extends StatefulWidget {
  const EmailConfirmationPendingScreen({super.key});

  @override
  State<EmailConfirmationPendingScreen> createState() =>
      _EmailConfirmationPendingScreenState();
}

class _EmailConfirmationPendingScreenState
    extends State<EmailConfirmationPendingScreen> {
  static const _cooldownDuration = Duration(seconds: 60);

  final TextEditingController _codeController = TextEditingController();
  Timer? _cooldownTimer;
  int _secondsLeft = 0;
  int _lastHandledResend = 0;

  /// The message under the boxes. Only a failed verify lands here; a failed
  /// resend is a toast, because it says nothing about the code that was typed.
  String? _codeError;
  AuthAwaitingEmailConfirmation? _previous;

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

  bool get _isComplete => _codeController.text.length == kSignupOtpLength;

  void _verify() {
    if (!_isComplete) return;
    FocusManager.instance.primaryFocus?.unfocus();
    context.read<AuthBloc>().add(AuthVerifyOtpEvent(_codeController.text));
  }

  void _resend() {
    if (_secondsLeft > 0) return;
    context.read<AuthBloc>().add(const AuthResendOtpEvent());
  }

  void _goBackToSignup(String email) {
    context.read<AuthBloc>().add(const AuthSessionCheckEvent());
    context.go('/login', extra: email);
  }

  void _onCodeChanged(String _) {
    // Editing the code answers the error; it comes back only if the next
    // attempt fails too.
    setState(() => _codeError = null);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (prev, curr) {
        // The listener only receives the new state; keep the one before it
        // so a finished verify can be told from a finished resend.
        _previous = prev is AuthAwaitingEmailConfirmation ? prev : null;
        return curr is AuthAwaitingEmailConfirmation;
      },
      listener: (context, state) {
        if (state is! AuthAwaitingEmailConfirmation) return;
        // Start the cooldown off the bloc's counter rather than off the tap, so
        // it only runs when the email actually went out.
        if (state.resendCount > _lastHandledResend) {
          _lastHandledResend = state.resendCount;
          _startCooldown();
        }
        // The bloc keeps one error for both actions; which one just finished
        // says where the message belongs.
        final previous = _previous;
        final error = state.error;
        if (previous == null || error == null) return;
        if (previous.isVerifying && !state.isVerifying) {
          setState(() => _codeError = error);
        } else if (previous.isResending && !state.isResending) {
          showAuthToast(context, error);
        }
      },
      buildWhen: (prev, curr) => curr is AuthAwaitingEmailConfirmation,
      builder: (context, state) {
        // buildWhen keeps the last pending state around while the router is
        // still tearing this route down after a successful verify, so this only
        // guards the window before the redirect lands.
        if (state is! AuthAwaitingEmailConfirmation) {
          return const Scaffold(backgroundColor: AuthColors.surface);
        }
        return _buildPage(context, state);
      },
    );
  }

  Widget _buildPage(
    BuildContext context,
    AuthAwaitingEmailConfirmation pending,
  ) {
    final email = pending.email.trim();
    final canResend = !pending.isResending && _secondsLeft == 0;
    final error = _codeError;

    return PopScope(
      canPop: false,
      child: AuthPage(
        onBack: email.isEmpty ? null : () => _goBackToSignup(email),
        footer: Center(
          child: AuthTextLink(
            label: 'Wrong email? Go back',
            color: AuthColors.muted,
            onTap: email.isEmpty ? null : () => _goBackToSignup(email),
          ),
        ),
        children: [
          AuthHeader(
            title: 'Enter your code',
            subtitle: 'We sent a verification code to',
            emphasis: email,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AuthCodeBoxes(
                controller: _codeController,
                enabled: !pending.isVerifying,
                hasError: error != null,
                onChanged: _onCodeChanged,
                onSubmitted: (_) => _verify(),
              ),
              if (error != null) ...[
                const SizedBox(height: 6),
                AuthErrorLine(message: error),
              ],
            ],
          ),
          AuthPrimaryButton(
            label: 'Verify & continue',
            loading: pending.isVerifying,
            loadingLabel: 'Verifying…',
            onPressed: _isComplete ? _verify : null,
          ),
          Center(child: _buildResend(pending, canResend)),
          Text(
            'The same email also has a confirmation link if you would '
            'rather tap that.',
            style: AuthText.small,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// "Resend code in 42s" is plain muted text while the cooldown runs; the
  /// link only appears once a resend is possible.
  Widget _buildResend(AuthAwaitingEmailConfirmation pending, bool canResend) {
    if (pending.isResending) {
      return const SizedBox(
        height: 21,
        child: Center(child: AuthSpinner(size: 16, color: AuthColors.brand)),
      );
    }
    if (_secondsLeft > 0) {
      return Text(
        'Resend code in ${_secondsLeft}s',
        style: AuthText.body,
        textAlign: TextAlign.center,
      );
    }
    return AuthTextLink(
      label: "Didn't get a code? Resend",
      onTap: canResend ? _resend : null,
    );
  }
}
