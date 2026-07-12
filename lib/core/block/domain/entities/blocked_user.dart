/// A user the current user has blocked, with the profile fields needed to show
/// them in the "Blocked users" management screen.
class BlockedUser {
  final String userId;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final DateTime blockedAt;

  const BlockedUser({
    required this.userId,
    required this.blockedAt,
    this.username,
    this.fullName,
    this.avatarUrl,
  });

  /// Best display name available for the blocked user.
  String get displayName {
    if (username != null && username!.trim().isNotEmpty) return '@$username';
    if (fullName != null && fullName!.trim().isNotEmpty) return fullName!;
    return 'Nook user';
  }
}
