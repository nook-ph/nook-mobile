import 'package:nook/features/profile/domain/i_profile_repository.dart';

class UpdateProfileUseCase {
  final IProfileRepository repository;

  const UpdateProfileUseCase(this.repository);

  Future<void> call({
    required String userId,
    String? name,
    String? bio,
    String? avatarUrl,
    String? username,
  }) async {
    if (userId.trim().isEmpty) throw ArgumentError('User id is required.');

    if (name == null && username == null && bio == null && avatarUrl == null)
      return;

    return repository.updateProfile(
      userId: userId,
      name: name,
      username: username, 
      bio: bio,
      avatarUrl: avatarUrl,
    );
  }
}
