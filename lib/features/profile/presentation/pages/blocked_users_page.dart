import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/block/domain/entities/blocked_user.dart';
import 'package:nook/core/block/domain/use_cases/get_blocked_users_usecase.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/injection_container.dart';

/// Lets a user review and unblock people they've blocked. Reachable from
/// Settings. Blocking itself happens from a review's overflow menu.
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  static const _brandGreen = Color(0xFF344E41);

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
      final users = await sl<GetBlockedUsersUseCase>().call();
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
    setState(() => _unblocking.add(user.userId));
    try {
      await context.read<BlockCubit>().unblock(user.userId);
      if (!mounted) return;
      setState(() {
        _users = _users.where((u) => u.userId != user.userId).toList();
        _unblocking.remove(user.userId);
      });
      showPrimaryToast(context, '${user.displayName} unblocked.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _unblocking.remove(user.userId));
      showPrimaryToast(context, 'Could not unblock. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Blocked Users',
          style: TextStyle(color: Colors.black87, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _brandGreen));
    }
    if (_error) {
      return _CenteredMessage(
        message: 'Could not load blocked users.',
        actionLabel: 'Retry',
        onAction: _load,
      );
    }
    if (_users.isEmpty) {
      return const _CenteredMessage(
        message: "You haven't blocked anyone.\nBlocked users appear here.",
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _users.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
      itemBuilder: (context, index) {
        final user = _users[index];
        final isUnblocking = _unblocking.contains(user.userId);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFEFEFEF),
            backgroundImage:
                (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                ? const Icon(Icons.person, color: Colors.black38)
                : null,
          ),
          title: Text(user.displayName),
          trailing: TextButton(
            onPressed: isUnblocking ? null : () => _unblock(user),
            style: TextButton.styleFrom(foregroundColor: _brandGreen),
            child: isUnblocking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _brandGreen,
                    ),
                  )
                : const Text('Unblock'),
          ),
        );
      },
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
