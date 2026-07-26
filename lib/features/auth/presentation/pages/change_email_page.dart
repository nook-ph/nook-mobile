import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChangeEmailScreen extends StatefulWidget {
  final String? currentEmail;

  const ChangeEmailScreen({super.key, this.currentEmail});

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
    final current =
        widget.currentEmail?.trim() ??
        Supabase.instance.client.auth.currentUser?.email?.trim() ??
        '';
    _emailController.text = current;
    _emailController.addListener(() {
      if (_emailError != null) {
        final text = _emailController.text.trim();
        if (_isValidEmail(text) || text.isEmpty) {
          setState(() => _emailError = null);
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    debugPrint('[EmailVerification] Change email submit: email=$email');
    if (!_isValidEmail(email)) {
      debugPrint('[EmailVerification] Invalid email entered.');
      setState(() => _emailError = 'This email is invalid');
      return;
    }

    setState(() {
      _emailError = null;
      _isLoading = true;
    });

    try {
      debugPrint('[EmailVerification] Updating user email.');
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: email),
        emailRedirectTo: 'ph.nook.app://login-callback',
      );
      debugPrint('[EmailVerification] Update email request completed.');
      if (!mounted) return;
      showPrimaryToast(context, 'Verification sent to $email');
      context.pop();
    } on AuthException catch (e) {
      debugPrint('[EmailVerification] Update email failed: ${e.message}');
      if (mounted) {
        showPrimaryToast(context, e.message);
      }
    } catch (_) {
      debugPrint('[EmailVerification] Update email failed with unknown error.');
      if (mounted) {
        showPrimaryToast(context, 'Unable to update email. Try again.');
      }
    } finally {
      debugPrint('[EmailVerification] Change email submit finished.');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailController.text.trim();
    final canSubmit = email.isNotEmpty && !_isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AdaptiveTap(
          onTap: () => context.pop(),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.arrow_back),
          ),
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
                'Update your email',
                style: context.textTheme.titleLargeSemi,
              ),
              const SizedBox(height: 8),
              Text(
                'We will send a new verification link.',
                style: context.textTheme.bodySmall!.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email Address',
                  hintStyle: context.textTheme.bodySmall!.copyWith(
                    color: const Color(0xFFA8AAAA),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.black87),
                  ),
                ),
              ),
              if (_emailError != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _emailError!,
                    style: context.textTheme.bodySmall!.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: AdaptiveElevatedButton(
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
                          'Send verification',
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
    );
  }
}
