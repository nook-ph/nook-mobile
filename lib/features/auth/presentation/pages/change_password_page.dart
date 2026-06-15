import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

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
  }

  void _onNewPasswordChanged() {
    if (_newPasswordError != null && _newPasswordController.text.length >= 6) {
      setState(() => _newPasswordError = null);
    }
    if (_confirmPasswordError != null &&
        _confirmPasswordController.text == _newPasswordController.text) {
      setState(() => _confirmPasswordError = null);
    }
  }

  void _onConfirmPasswordChanged() {
    if (_confirmPasswordError != null &&
        _confirmPasswordController.text == _newPasswordController.text) {
      setState(() => _confirmPasswordError = null);
    }
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;

    if (_newPasswordController.text.length < 6) {
      setState(
        () => _newPasswordError = 'Password must be at least 6 characters',
      );
      valid = false;
    } else {
      setState(() => _newPasswordError = null);
    }

    if (_confirmPasswordController.text != _newPasswordController.text) {
      setState(() => _confirmPasswordError = 'Passwords do not match');
      valid = false;
    } else {
      setState(() => _confirmPasswordError = null);
    }

    return valid;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      if (!mounted) return;

      showPrimaryToast(context, 'Password updated successfully');

      // Let the AuthBloc re-evaluate session, then router redirect handles navigation
      context.read<AuthBloc>().add(const AuthSessionCheckEvent());
    } on AuthException catch (e) {
      if (mounted) showPrimaryToast(context, e.message);
    } catch (_) {
      if (mounted)
        showPrimaryToast(context, 'Unable to update password. Try again.');
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
    final canSubmit =
        _newPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        !_isLoading;

    final isRecoveryFlow =
        context.read<AuthBloc>().state is AuthPasswordRecovery;

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
        onPopInvoked: (didPop) {
          if (didPop) return;
          if (isRecoveryFlow) return;
          _onBackPressed();
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: !isRecoveryFlow,
            leading: isRecoveryFlow
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _onBackPressed,
                  ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 28),
                  Image.asset('assets/logos/logoT.png', width: 110),
                  const SizedBox(height: 22),
                  Text(
                    'Change your password',
                    style: context.textTheme.titleLargeSemi,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter and confirm your new password.',
                    style: context.textTheme.bodySmall!.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _PasswordField(
                    controller: _newPasswordController,
                    hint: 'New Password',
                    obscure: _obscureNew,
                    onToggle: () => setState(() => _obscureNew = !_obscureNew),
                    error: _newPasswordError,
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    controller: _confirmPasswordController,
                    hint: 'Confirm Password',
                    obscure: _obscureConfirm,
                    onToggle: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                    error: _confirmPasswordError,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: canSubmit ? _submit : null,
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
                      child: _isLoading
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
                              'Update password',
                              style: context.textTheme.bodyLargeMed.copyWith(
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    this.error,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.textTheme.bodySmall!.copyWith(color: const Color(0xFFA8AAAA)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black87),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFFA8AAAA),
              ),
              onPressed: onToggle,
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: context.textTheme.bodySmall!.copyWith(color: Colors.red)),
        ],
      ],
    );
  }
}
