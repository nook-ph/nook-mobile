import 'package:nook/core/block/domain/repositories/i_block_repository.dart';

class GetBlockedUserIdsUseCase {
  final IBlockRepository repository;

  GetBlockedUserIdsUseCase(this.repository);

  Future<Set<String>> call() => repository.getBlockedUserIds();
}
