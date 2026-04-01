import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';

class SignupDetailsScreen extends StatefulWidget {
  final String? email;

  const SignupDetailsScreen({super.key, this.email});

  @override
  State<SignupDetailsScreen> createState() => _SignupDetailsScreenState();
}

class _SignupDetailsScreenState extends State<SignupDetailsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _nameError;
  String? _passwordError;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      if (_nameError != null && _nameController.text.trim().isNotEmpty) {
        _nameError = null;
      }
      setState(() {});
    });

    _passwordController.addListener(() {
      if (_passwordError != null && _passwordController.text.length >= 8) {
        _passwordError = null;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emailFromExtra = GoRouterState.of(context).extra as String?;
    final email = (widget.email ?? emailFromExtra ?? '').trim();

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go('/');
        }

        if (state is AuthError) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final name = _nameController.text.trim();
        final password = _passwordController.text;
        final canSubmit = name.isNotEmpty && password.isNotEmpty && !isLoading;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => context.go('/login', extra: email),
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Gap(60),
                  Column(
                    children: [
                      Image.asset('assets/logos/logoT.png', width: 110),
                      const Gap(22),
                      const Text(
                        'Continue your account',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        'Signing up as $email',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const Gap(24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What should we call you?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const Gap(8),
                      TextFormField(
                        controller: _nameController,
                        keyboardType: TextInputType.name,
                        decoration: _inputDecoration('Name'),
                      ),
                      if (_nameError != null) ...[
                        const Gap(8),
                        Text(
                          _nameError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const Gap(24),
                      const Text(
                        'Create a password',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const Gap(8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration('Password').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFFA8AAAA),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      if (_passwordError != null) ...[
                        const Gap(8),
                        Text(
                          _passwordError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const Gap(32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canSubmit
                              ? () => _onContinuePressed(context, email)
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
                              : const Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _onContinuePressed(BuildContext context, String email) {
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    String? nameError;
    String? passwordError;

    if (name.isEmpty) {
      nameError = 'Name is required';
    }

    if (password.length < 8) {
      passwordError = 'Password must contain at least 8 characters';
    }

    if (nameError != null || passwordError != null) {
      setState(() {
        _nameError = nameError;
        _passwordError = passwordError;
      });
      return;
    }

    setState(() {
      _nameError = null;
      _passwordError = null;
    });

    context.read<AuthBloc>().add(
      AuthSignUpEvent(email: email, name: name, password: password),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFA8AAAA), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.black87),
      ),
    );
  }
}
