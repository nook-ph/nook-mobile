import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Asks Supabase to move the account to a new email. Swappable in tests.
typedef UpdateEmail = Future<void> Function(String email);

Future<void> _supabaseUpdateEmail(String email) async {
  await Supabase.instance.client.auth.updateUser(
    UserAttributes(email: email),
    emailRedirectTo: 'ph.nook.app://login-callback',
  );
}

/// "Update your email" from Settings (Figma D10–D13, F7).
class ChangeEmailScreen extends StatefulWidget {
  final String? currentEmail;
  final UpdateEmail updateEmail;

  const ChangeEmailScreen({
    super.key,
    this.currentEmail,
    this.updateEmail = _supabaseUpdateEmail,
  });

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final TextEditingController _emailController = TextEditingController();
  String? _emailError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.text =
        widget.currentEmail?.trim() ?? _signedInEmail() ?? '';
    _emailController.addListener(() {
      setState(() {
        if (_emailError != null) {
          final text = _emailController.text.trim();
          if (isValidAuthEmail(text) || text.isEmpty) _emailError = null;
        }
      });
    });
  }

  /// The account's email, when Supabase is up (it is not in widget tests).
  String? _signedInEmail() {
    try {
      return Supabase.instance.client.auth.currentUser?.email?.trim();
    } catch (_) {
      return null;
    }
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

    try {
      await widget.updateEmail(email);
      if (!mounted) return;
      showAuthToast(context, 'Verification sent to $email', success: true);
      context.pop();
    } on AuthException catch (e) {
      if (mounted) showAuthToast(context, e.message);
    } catch (_) {
      if (mounted) showAuthToast(context, 'Unable to update email. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailController.text.trim();
    final canSubmit = email.isNotEmpty && _emailError == null && !_isLoading;

    return AuthPage(
      onBack: () => context.pop(),
      children: [
        const AuthHeader(
          title: 'Update your email',
          subtitle: 'We will send a new verification link.',
        ),
        AuthTextField(
          controller: _emailController,
          label: 'New email',
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
            if (canSubmit) _submit();
          },
        ),
        AuthPrimaryButton(
          label: 'Send verification',
          loading: _isLoading,
          loadingLabel: 'Sending…',
          onPressed: canSubmit ? _submit : null,
        ),
      ],
    );
  }
}
