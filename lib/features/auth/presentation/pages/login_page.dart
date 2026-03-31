import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

class LoginPasswordScreen extends StatefulWidget {
  final String email;

  const LoginPasswordScreen({
    super.key,
    required this.email,
  });

  @override
  State<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
}

class _LoginPasswordScreenState extends State<LoginPasswordScreen> {
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
    
    _passwordController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPasswordValid = _passwordController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              children: [
                const Gap(40),
                // Logo & Title
                Column(
                  children: [
                    Image.asset('assets/logos/logoT.png', width: 110),
                    const Gap(22),
                    const Text(
                      'Log in',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Gap(8),
                    Text(
                      'Welcome back, ${widget.email}',
                      style: const TextStyle(
                        color: Color(0xFFA8AAAA),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const Gap(32),
                
                // Input fields
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Read-only Email Field
                    TextField(
                      controller: _emailController,
                      readOnly: true, // Prevents editing
                      style: const TextStyle(color: Colors.black54),
                      decoration: InputDecoration(
                        fillColor: Colors.grey.shade100,
                        filled: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                      ),
                    ),
                    const Gap(16),
                    
                    // Password Field
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: const TextStyle(
                          color: Color(0xFFA8AAAA),
                          fontSize: 14,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.black87),
                        ),
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
                    const Gap(8),
                    
                    // Forgot Password Link
                    TextButton(
                      onPressed: () {
                        // TODO: Implement Forgot Password navigation
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: Color(0xFF344E41),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Gap(24),
                    
                    // Log In Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isPasswordValid
                            ? () {
                                // TODO: Call Supabase Auth signInWithPassword
                                // final password = _passwordController.text;
                              }
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
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
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
  }
}