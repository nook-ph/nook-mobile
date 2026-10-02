import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/constants/app_constants.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sends the password reset email. Swappable in tests.
typedef SendPasswordReset = Future<void> Function(String email);

Future<void> _supabaseSendReset(String email) {
  return Supabase.instance.client.auth.resetPasswordForEmail(
    email,
    redirectTo: AppConstants.emailRedirectUri,
  );
}

/// "Forgot your password?" (Figma D1–D3, D5) and, once the link is out,
/// "Check your email" (D4): a screen that stays instead of a toast that
/// disappears.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.sendReset = _supabaseSendReset});

  final SendPasswordReset sendReset;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  String? _emailError;
  bool _isLoading = false;

  /// The address the link went to. Set, the page shows "Check your email".
  String? _sentTo;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!isValidAuthEmail(email)) {
      setState(() => _emailError = 'This email is invalid');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _emailError = null;
      _isLoading = true;
    });
    final sent = await _send(email);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (sent) _sentTo = email;
    });
  }

  /// "Didn't get it? Send again": the same call, answered with a toast since
  /// the page already says where the link went.
  Future<void> _sendAgain() async {
    final email = _sentTo;
    if (email == null || _isLoading) return;
    setState(() => _isLoading = true);
    final sent = await _send(email);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (sent) {
      showAuthToast(
        context,
        'Password reset link sent to $email',
        success: true,
      );
    }
  }

  /// Sends the link and reports a failure as a toast. True when it went out.
  Future<bool> _send(String email) async {
    try {
      await widget.sendReset(email);
      return true;
    } on AuthException catch (e) {
      if (mounted) showAuthToast(context, e.message);
    } catch (_) {
      if (mounted) {
        showAuthToast(context, 'Unable to send reset link. Try again.');
      }
    }
    return false;
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    return sentTo == null ? _buildForm() : _buildSent(sentTo);
  }

  Widget _buildForm() {
    final email = _emailController.text.trim();
    final canSubmit = email.isNotEmpty && _emailError == null;

    return AuthPage(
      onBack: _leave,
      children: [
        const AuthHeader(
          title: 'Forgot your password?',
          subtitle: "Enter your email and we'll send a reset link.",
        ),
        AuthTextField(
          controller: _emailController,
          label: 'Email',
          hintText: 'Email address',
          errorText: _emailError,
          autofocus: true,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) {
            if (canSubmit && !_isLoading) _submit();
          },
        ),
        AuthPrimaryButton(
          label: 'Send reset link',
          loading: _isLoading,
          loadingLabel: 'Sending…',
          onPressed: canSubmit ? _submit : null,
        ),
      ],
    );
  }

  Widget _buildSent(String email) {
    return AuthPage(
      onBack: _leave,
      topPadding: 40,
      gap: 12,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            // The design's 4 spacer and the second 12 gap it brings.
            padding: EdgeInsets.only(bottom: 16),
            child: AuthIconBadge(
              icon: LucideIcons.mail,
              background: AuthColors.successTint,
            ),
          ),
        ),
        const Text('Check your email', style: AuthText.title),
        Padding(
          // The design's 8 spacer and the second 12 gap it brings.
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            'Password reset link sent to $email. Open it on this phone to '
            'choose a new password.',
            style: AuthText.body,
          ),
        ),
        AuthPrimaryButton(label: 'Back to log in', onPressed: _leave),
        Center(
          child: _isLoading
              ? const SizedBox(
                  height: 21,
                  child: Center(
                    child: AuthSpinner(size: 16, color: AuthColors.brand),
                  ),
                )
              : AuthTextLink(
                  label: "Didn't get it? Send again",
                  onTap: _sendAgain,
                ),
        ),
      ],
    );
  }
}
