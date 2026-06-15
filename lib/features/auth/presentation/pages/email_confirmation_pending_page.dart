import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/constants/app_constants.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class EmailConfirmationPendingScreen extends StatefulWidget {
  const EmailConfirmationPendingScreen({super.key});

  @override
  State<EmailConfirmationPendingScreen> createState() =>
      _EmailConfirmationPendingScreenState();
}

class _EmailConfirmationPendingScreenState
    extends State<EmailConfirmationPendingScreen> {
  static const _cooldownDuration = Duration(seconds: 60);

  Timer? _cooldownTimer;
  bool _isSending = false;
  bool _cooldownActive = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _resendConfirmationEmail(String email) async {
    debugPrint('[EmailVerification] Resend email tapped: email=$email');
    if (_isSending || _cooldownActive || email.isEmpty) {
      debugPrint(
        '[EmailVerification] Resend blocked. isSending=$_isSending, cooldown=$_cooldownActive, emailEmpty=${email.isEmpty}',
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      debugPrint('[EmailVerification] Sending resend request.');
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: AppConstants.emailRedirectUri,
      );
      debugPrint('[EmailVerification] Resend request completed.');

      if (!mounted) return;

      setState(() => _cooldownActive = true);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(_cooldownDuration, () {
        if (!mounted) return;
        setState(() => _cooldownActive = false);
      });
    } on AuthException catch (error) {
      debugPrint('[EmailVerification] Resend failed: ${error.message}');
      if (mounted) {
        showPrimaryToast(context, error.message);
      }
    } catch (_) {
      debugPrint('[EmailVerification] Resend failed with unknown error.');
      if (mounted) {
        showPrimaryToast(context, 'Unable to resend email. Try again.');
      }
    } finally {
      debugPrint('[EmailVerification] Resend flow finished.');
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _goBackToSignup(String email) {
    context.read<AuthBloc>().add(const AuthSessionCheckEvent());
    context.go('/login', extra: email);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final email = authState is AuthAwaitingEmailConfirmation
        ? authState.email.trim()
        : '';

    final canResend = email.isNotEmpty && !_isSending && !_cooldownActive;

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
                  'Confirm your email',
                  style: context.textTheme.titleLargeSemi,
                ),
                const Gap(8),
                Text(
                  'We sent a confirmation link to $email',
                  style: context.textTheme.bodySmall!.copyWith(
                    color: const Color(0xFFA8AAAA),
                  ),
                  textAlign: TextAlign.center,
                ),
                const Gap(28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canResend
                        ? () => _resendConfirmationEmail(email)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF344E41),
                      disabledBackgroundColor: const Color(
                        0xFF344E41,
                      ).withOpacity(0.5),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white.withOpacity(0.8),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSending
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
                            _cooldownActive
                                ? '✓ Sent! Check your inbox'
                                : 'Resend email',
                            style: context.textTheme.bodyLargeMed.copyWith(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const Gap(16),
                TextButton(
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
  }
}
