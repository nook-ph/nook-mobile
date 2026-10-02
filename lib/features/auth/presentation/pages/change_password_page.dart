import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// Saves the new password on the signed-in account. Swappable in tests.
typedef UpdatePassword = Future<void> Function(String password);

Future<void> _supabaseUpdatePassword(String password) async {
  await Supabase.instance.client.auth.updateUser(
    UserAttributes(password: password),
  );
}

/// "Change your password" (Figma D6–D9). Opened from Settings, or from the
/// reset link, in which case there is no back arrow and leaving signs out.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    this.updatePassword = _supabaseUpdatePassword,
  });

  final UpdatePassword updatePassword;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newPasswordFocus = FocusNode();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _newPasswordError;
  String? _confirmPasswordError;
  bool _isLoading = false;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onNewPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
    _newPasswordFocus.addListener(() => setState(() {}));
  }

  void _onNewPasswordChanged() {
    setState(() {
      if (_newPasswordController.text.length >= kChangePasswordMinLength) {
        _newPasswordError = null;
      }
      if (_confirmPasswordController.text == _newPasswordController.text) {
        _confirmPasswordError = null;
      }
    });
  }

  void _onConfirmPasswordChanged() {
    setState(() {
      if (_confirmPasswordController.text == _newPasswordController.text) {
        _confirmPasswordError = null;
      }
    });
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newPasswordFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    final tooShort =
        _newPasswordController.text.length < kChangePasswordMinLength;
    final mismatch =
        _confirmPasswordController.text != _newPasswordController.text;
    setState(() {
      _newPasswordError = tooShort
          ? 'Password must be at least $kChangePasswordMinLength characters'
          : null;
      _confirmPasswordError = mismatch ? 'Passwords do not match' : null;
    });
    return !tooShort && !mismatch;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isLoading = true);

    try {
      await widget.updatePassword(_newPasswordController.text);
      if (!mounted) return;
      showAuthToast(context, 'Password updated successfully', success: true);
      // Let the AuthBloc re-evaluate session, then router redirect handles
      // navigation.
      final authBloc = context.read<AuthBloc>();
      final isRecoveryFlow = authBloc.state is AuthPasswordRecovery;
      authBloc.add(const AuthSessionCheckEvent());
      // Opened from Settings the state is already AuthAuthenticated, so the
      // re-check emits nothing new and no redirect follows.
      if (!isRecoveryFlow && context.canPop()) context.pop();
    } on AuthException catch (e) {
      if (mounted) showAuthToast(context, e.message);
    } catch (_) {
      if (mounted) {
        showAuthToast(context, 'Unable to update password. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onBackPressed() {
    if (_isExiting) return;
    final isRecoveryFlow =
        context.read<AuthBloc>().state is AuthPasswordRecovery;
    if (isRecoveryFlow) {
      setState(() => _isExiting = true);
      context.read<AuthBloc>().add(const AuthSignOutEvent());
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final newPassword = _newPasswordController.text;
    final canSubmit =
        newPassword.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        !_isLoading;
    final isRecoveryFlow =
        context.read<AuthBloc>().state is AuthPasswordRecovery;
    final helper = passwordHelper(
      value: newPassword,
      focused: _newPasswordFocus.hasFocus,
      minLength: kChangePasswordMinLength,
    );

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/');
        }
        if (state is AuthUnauthenticated || state is AuthLoggedOut) {
          context.go('/login');
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (isRecoveryFlow) return;
          _onBackPressed();
        },
        child: AuthPage(
          onBack: isRecoveryFlow ? null : _onBackPressed,
          children: [
            const AuthHeader(
              title: 'Change your password',
              subtitle: 'Enter and confirm your new password.',
            ),
            AuthTextField(
              controller: _newPasswordController,
              focusNode: _newPasswordFocus,
              label: 'New password',
              hintText: 'New password',
              errorText: _newPasswordError,
              helperText: helper?.text,
              helperColor: helper?.color,
              obscureText: _obscureNew,
              autofocus: true,
              enabled: !_isLoading,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              trailing: AuthPasswordToggle(
                obscured: _obscureNew,
                onTap: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            AuthTextField(
              controller: _confirmPasswordController,
              label: 'Confirm password',
              hintText: 'Confirm password',
              errorText: _confirmPasswordError,
              obscureText: _obscureConfirm,
              enabled: !_isLoading,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (canSubmit) _submit();
              },
              trailing: AuthPasswordToggle(
                obscured: _obscureConfirm,
                onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            AuthPrimaryButton(
              label: 'Update password',
              loading: _isLoading,
              loadingLabel: 'Updating…',
              onPressed: canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
