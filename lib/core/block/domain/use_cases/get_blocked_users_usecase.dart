import 'package:nook/core/block/domain/entities/blocked_user.dart';
import 'package:nook/core/block/domain/repositories/i_block_repository.dart';

class GetBlockedUsersUseCase {
  final IBlockRepository repository;

  GetBlockedUsersUseCase(this.repository);

  Future<List<BlockedUser>> call() => repository.getBlockedUsers();
}
