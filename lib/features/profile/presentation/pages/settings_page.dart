import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
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
                  onTap: () {},
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
                  onTap: () {},
                ),
              ],
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
