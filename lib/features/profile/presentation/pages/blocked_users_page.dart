import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/block/domain/entities/blocked_user.dart';
import 'package:nook/core/block/domain/use_cases/get_blocked_users_usecase.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/profile/presentation/widgets/profile_sheet.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/injection_container.dart';

/// Lets a user review and unblock people they've blocked. Reachable from
/// Settings. Blocking itself happens from a review's overflow menu.
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key, this.loadUsers});

  /// Fetches the blocked users. Defaults to [GetBlockedUsersUseCase].
  final Future<List<BlockedUser>> Function()? loadUsers;

  /// The name shown for [user]: the handle without its "@", else the full
  /// name.
  static String nameOf(BlockedUser user) {
    final username = user.username?.trim() ?? '';
    if (username.isNotEmpty) return username;
    final fullName = user.fullName?.trim() ?? '';
    return fullName.isNotEmpty ? fullName : 'Nook user';
  }

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  bool _loading = true;
  bool _error = false;
  List<BlockedUser> _users = const [];
  final Set<String> _unblocking = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final load = widget.loadUsers ?? sl<GetBlockedUsersUseCase>().call;
      final users = await load();
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    if (_unblocking.contains(user.userId)) return;
    final blockCubit = context.read<BlockCubit>();
    final name = BlockedUsersPage.nameOf(user);

    final confirmed = await showProfileConfirmSheet(
      context,
      title: 'Unblock $name?',
      message: 'You will see their reviews again.',
      confirmLabel: 'Unblock',
    );
    if (!confirmed || !mounted) return;

    setState(() => _unblocking.add(user.userId));
    try {
      await blockCubit.unblock(user.userId);
      if (!mounted) return;
      setState(() {
        _users = _users.where((u) => u.userId != user.userId).toList();
        _unblocking.remove(user.userId);
      });
      showPrimaryToast(context, '$name unblocked.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _unblocking.remove(user.userId));
      showPrimaryToast(context, 'Could not unblock. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileTokens.surface,
      appBar: const ProfileNavBar(title: 'Blocked users'),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _BlockedSkeleton();
    if (_error) {
      return SingleChildScrollView(
        child: ProfileMessage.error(
          title: 'Could not load blocked users.',
          onAction: _load,
          top: 160,
        ),
      );
    }
    if (_users.isEmpty) {
      return const SingleChildScrollView(
        child: ProfileMessage(
          icon: LucideIcons.ban,
          title: "You haven't blocked anyone.",
          subtitle: 'Blocked users appear here.',
          top: 160,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ProfileTokens.gutter,
            4,
            ProfileTokens.gutter,
            8,
          ),
          child: Text(
            'You do not see reviews from people you block.',
            style: ProfileTokens.text(12, color: ProfileTokens.muted),
          ),
        ),
        for (var i = 0; i < _users.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ProfileTokens.gutter,
            ),
            child: Column(
              children: [
                if (i > 0) const ProfileDivider(),
                _BlockedRow(
                  user: _users[i],
                  unblocking: _unblocking.contains(_users[i].userId),
                  onUnblock: () => _unblock(_users[i]),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One blocked person: avatar, name and the Unblock pill, which turns into
/// a spinner while the unblock runs.
class _BlockedRow extends StatelessWidget {
  const _BlockedRow({
    required this.user,
    required this.unblocking,
    required this.onUnblock,
  });

  final BlockedUser user;
  final bool unblocking;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final name = BlockedUsersPage.nameOf(user);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          ProfileAvatar(
            name: name,
            imageUrl: user.avatarUrl,
            size: 40,
            initialSize: 14,
            initialWeight: FontWeight.w500,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ProfileTokens.text(14, weight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          ProfilePillButton(
            label: 'Unblock',
            onTap: onUnblock,
            style: ProfilePillStyle.outlined,
            height: 36,
            fontSize: 12,
            // The spinner's pill keeps the width of the label it replaces.
            padding: unblocking ? 28 : 16,
            expand: false,
            busy: unblocking,
          ),
        ],
      ),
    );
  }
}

/// Four grey rows, shown while the list loads.
class _BlockedSkeleton extends StatelessWidget {
  const _BlockedSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading blocked users',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ProfileTokens.gutter,
          16,
          ProfileTokens.gutter,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(height: 24),
              const Row(
                children: [
                  ProfileSkeleton(width: 40, height: 40, radius: 20),
                  SizedBox(width: 12),
                  ProfileSkeleton(width: 140, height: 14),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
