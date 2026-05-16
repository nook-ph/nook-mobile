import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _textColor = Color(0xFF1A1A1A);
  static const _iconColor = Color(0xFF1A1A1A);
  static const _chevronColor = Color(0xFFBBBBBB);
  static const _dividerColor = Color(0xFFF0F0F0);

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
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.black87,
                size: 22,
              ),
              onPressed: () => Navigator.pop(context),
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
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _textColor,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Items ──────────────────────────────────────────────
                  _buildItem(
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
                    icon: Icons.vpn_key_outlined,
                    label: 'Change Password',
                    onTap: () {},
                  ),
                  const Divider(color: _dividerColor, height: 1),
                  _buildItem(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    onTap: () => _showLogoutDialog(context),
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
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.black.withOpacity(0.04),
      highlightColor: Colors.black.withOpacity(0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Icon(icon, size: 22, color: _iconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w400,
                  color: _textColor,
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
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Log out',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      content: const Text('Are you sure you want to log out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            ctx.read<AuthBloc>().add(const AuthSignOutEvent());
            Navigator.pop(ctx);
          },
          child: const Text('Log out', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
