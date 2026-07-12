import 'package:nook/core/block/domain/repositories/i_block_repository.dart';

class BlockUserUseCase {
  final IBlockRepository repository;

  BlockUserUseCase(this.repository);

  Future<void> call(String blockedUserId) {
    if (blockedUserId.trim().isEmpty) {
      throw ArgumentError('Blocked user id is required.');
    }
    return repository.blockUser(blockedUserId);
  }
}
