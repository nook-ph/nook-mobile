
abstract class IProfileRepository {
  Future<void> updateProfile({
    required String userId,
    String? name,
    String? bio,
    String? avatarUrl,
    String? username,
  });
}