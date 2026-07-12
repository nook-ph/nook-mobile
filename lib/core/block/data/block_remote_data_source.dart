import 'package:nook/core/block/domain/entities/blocked_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to the `blocked_users` table. Every operation is scoped to the current
/// authenticated user; RLS additionally enforces `blocker_id = auth.uid()`.
class BlockRemoteDataSource {
  final SupabaseClient supabase;

  BlockRemoteDataSource(this.supabase);

  String _requireUserId() {
    final id = supabase.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw Exception('You must be signed in to manage blocked users.');
    }
    return id;
  }

  Future<Set<String>> getBlockedUserIds() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) return <String>{};

    final rows = await supabase
        .from('blocked_users')
        .select('blocked_id')
        .eq('blocker_id', uid);

    return rows
        .map((row) => row['blocked_id'] as String?)
        .whereType<String>()
        .toSet();
  }

  Future<List<BlockedUser>> getBlockedUsers() async {
    final uid = _requireUserId();

    final rows = await supabase
        .from('blocked_users')
        .select(
          'blocked_id, created_at, '
          'blocked:profiles!blocked_users_blocked_id_fkey'
          '(username, full_name, avatar_url)',
        )
        .eq('blocker_id', uid)
        .order('created_at', ascending: false);

    return rows.map((row) {
      final profile = row['blocked'] as Map<String, dynamic>?;
      return BlockedUser(
        userId: row['blocked_id'] as String,
        blockedAt:
            DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.now(),
        username: profile?['username'] as String?,
        fullName: profile?['full_name'] as String?,
        avatarUrl: profile?['avatar_url'] as String?,
      );
    }).toList();
  }

  Future<void> blockUser(String blockedUserId) async {
    final uid = _requireUserId();
    await supabase.from('blocked_users').upsert({
      'blocker_id': uid,
      'blocked_id': blockedUserId,
    });
  }

  Future<void> unblockUser(String blockedUserId) async {
    final uid = _requireUserId();
    await supabase
        .from('blocked_users')
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_id', blockedUserId);
  }
}
