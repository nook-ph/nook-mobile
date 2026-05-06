import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/core/utils/toast_helper.dart';

class EmailEntryScreen extends StatefulWidget {
  const EmailEntryScreen({super.key});

  @override
  State<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends State<EmailEntryScreen> {
  final TextEditingController _emailController = TextEditingController();
  String? _emailError;
  bool _didPrefillFromExtra = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      if (_emailError != null) {
        final text = _emailController.text.trim();
        if (_isValidEmail(text) || text.isEmpty) {
          _emailError = null;
        }
      }
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didPrefillFromExtra) {
      return;
    }

    final email = GoRouterState.of(context).extra as String?;
    if (email != null && email.trim().isNotEmpty) {
      _emailController.text = email.trim();
    }

    _didPrefillFromExtra = true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailController.text.trim();

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthEmailChecked) {
          if (state.exists) {
            context.go('/login-password', extra: state.email);
          } else {
            context.go('/signup-details', extra: state.email);
          }
        }

        if (state is AuthError) {
          showPrimaryToast(context, state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        final canSubmit = email.isNotEmpty && !isLoading;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
            ),
          ),
          body: SingleChildScrollView(
            // Added to prevent overflow with the new buttons
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    const Gap(60),
                    Column(
                      children: [
                        Image.asset('assets/logos/logoT.png', width: 110),
                        const Gap(22),
                        const Text(
                          'Log in or Sign up',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Gap(24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'Email Address',
                        hintStyle: const TextStyle(
                          color: Color(0xFFA8AAAA),
                          fontSize: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black87),
                        ),
                      ),
                    ),
                    if (_emailError != null) ...[
                      const Gap(8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _emailError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                    const Gap(16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canSubmit
                            ? () => _onContinuePressed(context)
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
                    const Gap(24),
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFE0E0E0),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                            color: Color(0xFFE0E0E0),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const Gap(24),
                    _buildSocialButton(
                      text: 'Continue with Google',
                      icon: Image.asset(
                        'assets/logos/googleLogo.png',
                        height: 20,
                        width: 20,
                      ),
                      onPressed: () {
                        context.read<AuthBloc>().add(
                          const AuthSignInWithGoogleEvent(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    if (Platform.isIOS)         
                      _buildSocialButton(
                        text: 'Continue with Apple',
                        icon: const Icon(
                          Icons.apple,
                          color: Colors.black,
                          size: 28,
                        ),
                        onPressed: () {
                          // TODO: Implement Apple Sign-In
                          context.read<AuthBloc>().add(
                            const AuthSignInWithAppleEvent(),
                          );
                        },
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

  void _onContinuePressed(BuildContext context) {
    final email = _emailController.text.trim();

    if (!_isValidEmail(email)) {
      setState(() {
        _emailError = 'This email is invalid';
      });
      return;
    }

    setState(() {
      _emailError = null;
    });

    context.read<AuthBloc>().add(AuthCheckEmailEvent(email));
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  // Helper method for social buttons
  Widget _buildSocialButton({
    required String text,
    required Widget icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon,
        label: Text(
          text,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Color(0xFFE0E0E0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
        ),
      ),
    );
  }
}
