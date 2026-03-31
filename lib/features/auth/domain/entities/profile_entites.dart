class ProfileEntity {
  final String id;
  final String fullName;
  final String username;
  final String? avatarUrl;
  final DateTime createdAt;

  ProfileEntity({
    required this.id,
    required this.fullName,
    required this.username,
    required this.createdAt,
    this.avatarUrl,
  });
}
