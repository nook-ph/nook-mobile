import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/auth/presentation/widgets/auth_ui.dart';

/// What [AuthBloc] says when Supabase rejects the credentials. On this screen
/// the email is already known to exist, so it can only be the password.
const _invalidCredentials = 'Email or password is incorrect';

/// "Log in" for an existing account (Figma B6–B8, F8, F9).
class LoginPasswordScreen extends StatefulWidget {
  final String? email;

  const LoginPasswordScreen({super.key, this.email});

  @override
  State<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
}

class _LoginPasswordScreenState extends State<LoginPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// A wrong password sits under the field instead of in a toast (B7).
  String? _passwordError;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      // Selection moves notify too; only an edit answers the error.
      final text = _passwordController.text;
      if (text == _lastText) return;
      _lastText = text;
      setState(() => _passwordError = null);
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _logIn(String email) {
    FocusManager.instance.primaryFocus?.unfocus();
    context.read<AuthBloc>().add(
      AuthSignInEvent(email: email, password: _passwordController.text),
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
        if (state is AuthAuthenticated) {
          context.go('/');
          return;
        }
        if (state is AuthError) {
          if (state.message == _invalidCredentials) {
            setState(
              () => _passwordError = 'Incorrect password. Please try again.',
            );
          } else {
            showAuthToast(context, state.message);
          }
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final hasPassword = _passwordController.text.isNotEmpty;

        return AuthPage(
          onBack: () => context.go('/login'),
          children: [
            AuthHeader(
              title: 'Log in',
              subtitle: 'Welcome back,',
              emphasis: email,
            ),
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              hintText: 'Password',
              errorText: _passwordError,
              obscureText: _obscurePassword,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              enabled: !isLoading,
              onSubmitted: (_) {
                if (hasPassword && !isLoading) _logIn(email);
              },
              trailing: AuthPasswordToggle(
                obscured: _obscurePassword,
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AuthTextLink(
                label: 'Forgot password?',
                onTap: () => context.push('/forgot-password'),
              ),
            ),
            AuthPrimaryButton(
              label: 'Log in',
              loading: isLoading,
              loadingLabel: 'Logging in…',
              onPressed: hasPassword ? () => _logIn(email) : null,
            ),
          ],
        );
      },
    );
  }
}
