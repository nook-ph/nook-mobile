import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/auth/auth_return.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';

/// "Create your account" (Figma C1–C5).
class SignupDetailsScreen extends StatefulWidget {
  final String? email;

  const SignupDetailsScreen({super.key, this.email});

  @override
  State<SignupDetailsScreen> createState() => _SignupDetailsScreenState();
}

class _SignupDetailsScreenState extends State<SignupDetailsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  String? _nameError;
  String? _passwordError;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() {
        if (_nameController.text.trim().isNotEmpty) _nameError = null;
      });
    });
    _passwordController.addListener(() {
      setState(() {
        if (_passwordController.text.length >= kSignupPasswordMinLength) {
          _passwordError = null;
        }
      });
    });
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _onContinuePressed(String email) {
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final nameError = name.isEmpty ? 'Name is required' : null;
    final passwordError = password.length < kSignupPasswordMinLength
        ? 'Password must contain at least $kSignupPasswordMinLength characters'
        : null;

    setState(() {
      _nameError = nameError;
      _passwordError = passwordError;
    });
    if (nameError != null || passwordError != null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    context.read<AuthBloc>().add(
      AuthSignUpEvent(email: email, name: name, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailFromExtra = GoRouterState.of(context).extra as String?;
    final email = (widget.email ?? emailFromExtra ?? '').trim();

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthNeedsUsername) {
          context.go(
            '/username-setup',
            extra: {'fullName': state.fullName, 'avatarUrl': state.avatarUrl},
          );
          return;
        }
        if (state is AuthAwaitingEmailConfirmation) {
          context.go('/email-confirmation');
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
        final password = _passwordController.text;
        // Either field typed unlocks Continue, so pressing it can explain
        // what is still missing (C2) instead of staying silently grey.
        final canSubmit =
            (_nameController.text.trim().isNotEmpty || password.isNotEmpty) &&
            !isLoading;
        final helper = passwordHelper(
          value: password,
          focused: _passwordFocus.hasFocus,
          minLength: kSignupPasswordMinLength,
        );

        return AuthPage(
          onBack: () => context.canPop()
              ? context.pop()
              : context.go('/login', extra: email),
          children: [
            AuthHeader(
              title: 'Create your account',
              subtitle: 'Signing up as',
              emphasis: email,
            ),
            AuthTextField(
              controller: _nameController,
              label: 'Full name',
              hintText: 'Name',
              errorText: _nameError,
              autofocus: true,
              enabled: !isLoading,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              onSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            AuthTextField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              label: 'Password',
              hintText: 'Password',
              errorText: _passwordError,
              helperText: helper?.text,
              helperColor: helper?.color,
              obscureText: _obscurePassword,
              enabled: !isLoading,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (canSubmit) _onContinuePressed(email);
              },
              trailing: AuthPasswordToggle(
                obscured: _obscurePassword,
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            AuthPrimaryButton(
              label: 'Continue',
              loading: isLoading,
              loadingLabel: 'Creating account…',
              onPressed: canSubmit ? () => _onContinuePressed(email) : null,
            ),
          ],
        );
      },
    );
  }
}
