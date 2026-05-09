import 'package:nook/features/profile/data/profile_remote_data_source.dart';
import 'package:nook/features/profile/domain/i_profile_repository.dart';

class ProfileRepositoryImpl implements IProfileRepository {
  final ProfileRemoteDataSource remoteDataSource;

  const ProfileRepositoryImpl(this.remoteDataSource);

  @override
  Future<void> updateProfile({
    required String userId,
    String? name,
    String? bio,
    String? avatarUrl,
    String? username,
  }) {
    return remoteDataSource.updateProfile(
      userId: userId,
      name: name,
      username: username,
      bio: bio,
      avatarUrl: avatarUrl,
    );
  }
}
