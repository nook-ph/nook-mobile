import 'package:nook/core/block/domain/repositories/i_block_repository.dart';

class UnblockUserUseCase {
  final IBlockRepository repository;

  UnblockUserUseCase(this.repository);

  Future<void> call(String blockedUserId) {
    if (blockedUserId.trim().isEmpty) {
      throw ArgumentError('Blocked user id is required.');
    }
    return repository.unblockUser(blockedUserId);
  }
}
