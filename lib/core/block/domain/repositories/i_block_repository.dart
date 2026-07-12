import 'package:nook/core/block/domain/entities/blocked_user.dart';

/// User-to-user blocking. All operations are scoped to the current
/// authenticated user (enforced by RLS on `blocked_users`).
abstract class IBlockRepository {
  /// Ids of every user the current user has blocked (for feed filtering).
  Future<Set<String>> getBlockedUserIds();

  /// Blocked users with profile details, for the management screen.
  Future<List<BlockedUser>> getBlockedUsers();

  /// Blocks [blockedUserId].
  Future<void> blockUser(String blockedUserId);

  /// Unblocks [blockedUserId].
  Future<void> unblockUser(String blockedUserId);
}
