import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';

class LoginPasswordScreen extends StatefulWidget {
  final String? email;

  const LoginPasswordScreen({super.key, this.email});

  @override
  State<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
}

class _LoginPasswordScreenState extends State<LoginPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
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
          showPrimaryToast(context, state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final hasPassword = _passwordController.text.isNotEmpty;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: AdaptiveTap(
              onTap: () => context.go('/login'),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_back),
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    const Gap(40),
                    Column(
                      children: [
                        Image.asset('assets/logos/logoT.png', width: 110),
                        const Gap(22),
                        Text('Log in', style: context.textTheme.titleLargeSemi),
                        const Gap(8),
                        Text(
                          'Welcome back, $email',
                          style: context.textTheme.bodySmall!.copyWith(
                            color: const Color(0xFFA8AAAA),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const Gap(32),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Password',
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
                              borderSide: const BorderSide(
                                color: Colors.black87,
                              ),
                            ),
                            suffixIcon: AdaptiveTap(
                              onTap: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(0xFFA8AAAA),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Gap(8),
                        AdaptiveTextButton(
                          onPressed: () => context.go('/forgot-password'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot password?',
                            style: context.textTheme.bodyLargeMed.copyWith(
                              color: const Color(0xFF344E41),
                            ),
                          ),
                        ),
                        const Gap(24),
                        SizedBox(
                          width: double.infinity,
                          child: AdaptiveElevatedButton(
                            onPressed: hasPassword && !isLoading
                                ? () => context.read<AuthBloc>().add(
                                    AuthSignInEvent(
                                      email: email,
                                      password: _passwordController.text,
                                    ),
                                  )
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
                                    'Log In',
                                    style: context.textTheme.bodyLargeMed
                                        .copyWith(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
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
