import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _textColor = Color(0xFF1A1A1A);
  static const _iconColor = Color(0xFF1A1A1A);
  static const _chevronColor = Color(0xFFBBBBBB);
  static const _dividerColor = Color(0xFFF0F0F0);
  static const _dangerColor = Color(0xFFD9342B);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthLoggedOut) {
            showPrimaryToast(context, 'Logged out');
            context.go('/login');
          }
          if (state is AuthAccountDeleted) {
            showPrimaryToast(context, 'Your account has been deleted');
            context.go('/login');
          }
          if (state is AuthError) {
            showPrimaryToast(context, state.message);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.white,
            leading: AdaptiveTap(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.black87,
                  size: 22,
                ),
              ),
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),

                  // ── Title ──────────────────────────────────────────────
                  Text(
                    'Settings',
                    style: context.textTheme.titleMediumSemi.copyWith(
                      color: _textColor,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Items ──────────────────────────────────────────────
                  _buildItem(
                    context: context,
                    icon: Icons.mail_outline_rounded,
                    label: 'Change Email',
                    onTap: () {
                      final email = supabase
                          .Supabase
                          .instance
                          .client
                          .auth
                          .currentUser
                          ?.email;
                      debugPrint(
                        'Change Email tapped. currentUser.email=$email',
                      );
                      context.push('/change-email', extra: email);
                    },
                  ),
                  const Divider(color: _dividerColor, height: 1),
                  _buildItem(
                    context: context,
                    icon: Icons.vpn_key_outlined,
                    label: 'Change Password',
                    onTap: () => context.push('/change-password'),
                  ),
                  const Divider(color: _dividerColor, height: 1),
                  _buildItem(
                    context: context,
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    onTap: () => _showLogoutDialog(context),
                  ),
                  const Divider(color: _dividerColor, height: 1),
                  _buildItem(
                    context: context,
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete Account',
                    labelColor: _dangerColor,
                    iconColor: _dangerColor,
                    onTap: () => _showDeleteAccountDialog(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? labelColor,
    Color? iconColor,
  }) {
    final effectiveLabelColor = labelColor ?? _textColor;
    final effectiveIconColor = iconColor ?? _iconColor;
    return InkWell(
      onTap: onTap,
      splashColor: Colors.black.withOpacity(0.04),
      highlightColor: Colors.black.withOpacity(0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Icon(icon, size: 22, color: effectiveIconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: effectiveLabelColor,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: _chevronColor),
          ],
        ),
      ),
    );
  }
}

void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log out',
              style: ctx.textTheme.titleMediumSemi,
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to log out?',
              style: ctx.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AdaptiveTextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: ctx.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                AdaptiveTextButton(
                  onPressed: () {
                    ctx.read<AuthBloc>().add(const AuthSignOutEvent());
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'Log out',
                    style: ctx.textTheme.bodyMedium?.copyWith(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

bool _isEmailPasswordUser(supabase.User user) {
  final identities = user.identities;
  if (identities == null || identities.isEmpty) {
    return user.appMetadata['provider'] == 'email' ||
        (user.appMetadata['providers'] is List &&
            (user.appMetadata['providers'] as List).contains('email'));
  }
  return identities.any((i) => i.provider == 'email');
}

void _showDeleteAccountDialog(BuildContext context) {
  final currentUser = supabase.Supabase.instance.client.auth.currentUser;
  if (currentUser == null) return;
  final isEmailUser = _isEmailPasswordUser(currentUser);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _DeleteAccountDialog(isEmailUser: isEmailUser),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  final bool isEmailUser;
  const _DeleteAccountDialog({required this.isEmailUser});

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _inputController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isSubmitting) return false;
    final value = _inputController.text.trim();
    if (widget.isEmailUser) {
      return value.isNotEmpty;
    }
    return value == 'DELETE';
  }

  void _onSubmit() {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    final password = widget.isEmailUser
        ? _inputController.text
        : null;
    context.read<AuthBloc>().add(
          AuthDeleteAccountEvent(password: password),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = widget.isEmailUser;
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (_isSubmitting && state is! AuthLoading) {
          if (state is AuthAccountDeleted ||
              state is AuthUnauthenticated ||
              state is AuthError) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            if (state is! AuthError) {
              setState(() => _isSubmitting = false);
            } else {
              setState(() => _isSubmitting = false);
            }
          }
        }
      },
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete Account?',
                style: context.textTheme.titleMediumSemi,
              ),
              const SizedBox(height: 12),
              Text(
                'This will permanently delete your account and all associated data, including your reviews, lists, and saved cafes. This cannot be undone.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              if (isEmail)
                Text(
                  'Enter your password to confirm:',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                )
              else
                Text(
                  'Type DELETE in capitals to confirm:',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _inputController,
                obscureText: isEmail,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _onSubmit(),
                inputFormatters: isEmail
                    ? const []
                    : [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z]'),
                        ),
                        _UpperCaseFormatter(),
                      ],
                decoration: InputDecoration(
                  hintText: isEmail ? 'Password' : 'DELETE',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF344E41)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AdaptiveTextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AdaptiveTextButton(
                    onPressed: _canSubmit ? _onSubmit : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFD9342B),
                            ),
                          )
                        : Text(
                            'Delete Account',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: _canSubmit
                                  ? const Color(0xFFD9342B)
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
