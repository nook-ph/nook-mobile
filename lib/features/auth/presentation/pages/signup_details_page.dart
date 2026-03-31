import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

class SignupDetailsScreen extends StatelessWidget {
  final String email;

  const SignupDetailsScreen({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
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
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const Gap(24),

              // --- FORM FIELDS ---
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name Input
                  const Text(
                    'What should we call you?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const Gap(8),
                  TextField(
                    keyboardType: TextInputType.name,
                    decoration: _inputDecoration('Name'),
                  ),

                  const Gap(24),

                  // Password Input
                  const Text(
                    'Create a password',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const Gap(8),
                  TextField(
                    obscureText: true, // Hides the password dots
                    decoration: _inputDecoration('Password'),
                  ),

                  const Gap(32),

                  // --- CONTINUE BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          null, // Set to a function () {} when validation is ready
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF344E41),
                        disabledBackgroundColor: const Color(
                          0xFF344E41,
                        ).withOpacity(0.5),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white.withOpacity(
                          0.8,
                        ), // Matched opacity
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w500, // Matched to EmailEntryScreen
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(40), // Bottom padding
            ],
          ),
        ),
      ),
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
