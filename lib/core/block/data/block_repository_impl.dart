import 'package:nook/core/block/data/block_remote_data_source.dart';
import 'package:nook/core/block/domain/entities/blocked_user.dart';
import 'package:nook/core/block/domain/repositories/i_block_repository.dart';

class BlockRepositoryImpl implements IBlockRepository {
  final BlockRemoteDataSource remoteDataSource;

  BlockRepositoryImpl(this.remoteDataSource);

  @override
  Future<Set<String>> getBlockedUserIds() =>
      remoteDataSource.getBlockedUserIds();

  @override
  Future<List<BlockedUser>> getBlockedUsers() =>
      remoteDataSource.getBlockedUsers();

  @override
  Future<void> blockUser(String blockedUserId) =>
      remoteDataSource.blockUser(blockedUserId);

  @override
  Future<void> unblockUser(String blockedUserId) =>
      remoteDataSource.unblockUser(blockedUserId);
}
