import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/constants/app_constants.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/profile/presentation/pages/blocked_users_page.dart';
import 'package:nook/features/profile/presentation/profile_logic.dart';
import 'package:nook/features/profile/presentation/widgets/delete_account_sheet.dart';
import 'package:nook/features/profile/presentation/widgets/profile_sheet.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/features/public_profile/presentation/cubit/profile_visibility_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:url_launcher/url_launcher.dart';

/// Where the app's location access stands, as Settings reports it.
enum SettingsLocationStatus {
  on('On'),
  off('Off'),
  denied('Denied'),
  unknown('Not set');

  const SettingsLocationStatus(this.label);

  final String label;
}

/// Settings, in groups: Permissions, Account, Legal, then Log out and
/// Delete account on their own.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.currentUser, this.readLocationStatus});

  /// Who is signed in. Defaults to the Supabase session.
  final ValueGetter<supabase.User?>? currentUser;

  /// Reads the location permission. Defaults to asking Geolocator.
  final Future<SettingsLocationStatus> Function()? readLocationStatus;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  SettingsLocationStatus _locationStatus = SettingsLocationStatus.unknown;

  /// While the delete sheet is open it shows its own errors, under the
  /// field, so the page keeps its toast to itself.
  bool _deleteSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLocationStatus();
    final visibility = context.read<ProfileVisibilityCubit>();
    if (visibility.state.status != ProfileVisibilityStatus.loaded) {
      visibility.load();
    }
  }

  Future<void> _setHighlights(bool value) async {
    final ok = await context.read<ProfileVisibilityCubit>().setHighlightsPublic(
      value,
    );
    if (!ok && mounted) {
      showPrimaryToast(context, 'Could not save that. Please try again.');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocationStatus();
    }
  }

  supabase.User? get _user {
    final read = widget.currentUser;
    if (read != null) return read();
    return supabase.Supabase.instance.client.auth.currentUser;
  }

  Future<void> _refreshLocationStatus() async {
    final next = await (widget.readLocationStatus ?? _readLocationStatus)();
    if (!mounted) return;
    if (next != _locationStatus) {
      setState(() => _locationStatus = next);
    }
  }

  static Future<SettingsLocationStatus> _readLocationStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      final granted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (granted && serviceEnabled) return SettingsLocationStatus.on;
      if (granted && !serviceEnabled) return SettingsLocationStatus.off;
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return SettingsLocationStatus.denied;
      }
      return SettingsLocationStatus.unknown;
    } catch (_) {
      return SettingsLocationStatus.unknown;
    }
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        showPrimaryToast(context, 'Could not open the page. Please try again.');
      }
    }
  }

  Future<void> _confirmLogOut() async {
    final authBloc = context.read<AuthBloc>();
    final confirmed = await showProfileConfirmSheet(
      context,
      title: 'Log out?',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log out',
    );
    if (confirmed) authBloc.add(const AuthSignOutEvent());
  }

  Future<void> _deleteAccount() async {
    final user = _user;
    if (user == null) return;
    _deleteSheetOpen = true;
    await DeleteAccountSheet.show(
      context,
      isEmailUser: isEmailPasswordUser(user),
    );
    _deleteSheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    // Google and Apple accounts have no password and take their email from
    // the provider, so there is nothing to change here.
    final emailAccount = user == null || isEmailPasswordUser(user);
    final provider = user == null ? null : socialProviderName(user);
    final denied = _locationStatus == SettingsLocationStatus.denied;

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
          if (state is AuthError && !_deleteSheetOpen) {
            showPrimaryToast(context, state.message);
          }
        },
        child: Scaffold(
          backgroundColor: ProfileTokens.surface,
          appBar: const ProfileNavBar(title: 'Settings'),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Group(
                    title: 'Permissions',
                    rows: [
                      _SettingsRow(
                        icon: LucideIcons.mapPin,
                        label: 'Location',
                        value: _locationStatus.label,
                        valueColor: denied ? ProfileTokens.danger : null,
                        trailing: LucideIcons.chevronRight,
                        onTap: _openLocationSettings,
                      ),
                    ],
                  ),
                  _Group(
                    title: 'Privacy',
                    rows: [
                      BlocBuilder<
                        ProfileVisibilityCubit,
                        ProfileVisibilityState
                      >(
                        builder: (context, visibility) => _SwitchRow(
                          icon: LucideIcons.eye,
                          label: 'Show my gallery on my profile',
                          detail:
                              visibility.status ==
                                  ProfileVisibilityStatus.failed
                              ? 'Could not load this setting. Tap to try '
                                    'again.'
                              : 'Also shows how many cafes you have ranked. '
                                    'Your ranking stays private; reviews '
                                    'show either way.',
                          value: visibility.highlightsPublic,
                          onChanged:
                              visibility.status ==
                                  ProfileVisibilityStatus.loaded
                              ? _setHighlights
                              : null,
                          onRetry:
                              visibility.status ==
                                  ProfileVisibilityStatus.failed
                              ? () => context
                                    .read<ProfileVisibilityCubit>()
                                    .load()
                              : null,
                        ),
                      ),
                    ],
                  ),
                  _Group(
                    title: 'Account',
                    note: provider == null ? null : 'Signed in with $provider',
                    rows: [
                      if (emailAccount) ...[
                        _SettingsRow(
                          icon: LucideIcons.mail,
                          label: 'Change email',
                          trailing: LucideIcons.chevronRight,
                          onTap: () =>
                              context.push('/change-email', extra: user?.email),
                        ),
                        _SettingsRow(
                          icon: LucideIcons.lock,
                          label: 'Change password',
                          trailing: LucideIcons.chevronRight,
                          onTap: () => context.push('/change-password'),
                        ),
                      ],
                      _SettingsRow(
                        icon: LucideIcons.ban,
                        label: 'Blocked users',
                        trailing: LucideIcons.chevronRight,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BlockedUsersPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _Group(
                    title: 'Legal',
                    rows: [
                      _SettingsRow(
                        icon: LucideIcons.fileText,
                        label: 'Terms of Use (EULA)',
                        trailing: LucideIcons.externalLink,
                        onTap: () => _openUrl(AppConstants.eulaUrl),
                      ),
                      _SettingsRow(
                        icon: LucideIcons.shield,
                        label: 'Privacy Policy',
                        trailing: LucideIcons.externalLink,
                        onTap: () => _openUrl(AppConstants.privacyPolicyUrl),
                      ),
                    ],
                  ),
                  // Leaving and deleting sit apart from the settings above.
                  _Group(
                    rows: [
                      _SettingsRow(
                        icon: LucideIcons.logOut,
                        label: 'Log out',
                        onTap: _confirmLogOut,
                      ),
                      _SettingsRow(
                        icon: LucideIcons.trash2,
                        label: 'Delete account',
                        destructive: true,
                        onTap: _deleteAccount,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A block of rows with hairlines between them, under an optional muted
/// [title]. With no title the block opens with a hairline instead.
class _Group extends StatelessWidget {
  const _Group({required this.rows, this.title, this.note});

  final String? title;

  /// A muted line under the title ("Signed in with Google").
  final String? note;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final heading = title;
    final detail = note;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        16,
        ProfileTokens.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (heading == null)
            const ProfileDivider()
          else
            Text(
              heading,
              style: ProfileTokens.text(
                12,
                weight: FontWeight.w500,
                color: ProfileTokens.muted,
              ),
            ),
          if (detail != null)
            Text(
              detail,
              style: ProfileTokens.text(12, color: ProfileTokens.muted),
            ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const ProfileDivider(),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// One settings row: a 20 icon, the label, an optional value and an
/// optional trailing glyph (a chevron for in-app, an arrow for a link out).
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.valueColor,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;
  final Color? valueColor;
  final IconData? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? ProfileTokens.danger : ProfileTokens.ink;
    final status = value;
    final glyph = trailing;
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label, style: ProfileTokens.text(14, color: color)),
              ),
              if (status != null) ...[
                const SizedBox(width: 14),
                Text(
                  status,
                  style: ProfileTokens.text(
                    14,
                    color: valueColor ?? ProfileTokens.muted,
                  ),
                ),
              ],
              if (glyph != null) ...[
                const SizedBox(width: 14),
                Icon(glyph, size: 18, color: ProfileTokens.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings row with a switch: icon, label and a muted line under it.
/// The whole row toggles. While the value is unknown the switch is
/// disabled; after a failed read, a tap on the row reads it again.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.value,
    required this.onChanged,
    this.onRetry,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final change = onChanged;
    return MergeSemantics(
      child: AdaptiveTap(
        onTap: change != null ? () => change(!value) : onRetry,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 20, color: ProfileTokens.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: ProfileTokens.text(14)),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: ProfileTokens.text(12, color: ProfileTokens.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch.adaptive(
                value: value,
                onChanged: change,
                activeTrackColor: ProfileTokens.brand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
