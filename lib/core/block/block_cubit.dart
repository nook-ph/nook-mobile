import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/block/domain/use_cases/block_user_usecase.dart';
import 'package:nook/core/block/domain/use_cases/get_blocked_user_ids_usecase.dart';
import 'package:nook/core/block/domain/use_cases/unblock_user_usecase.dart';

/// App-wide cache of the ids the current user has blocked.
///
/// Provided above `MaterialApp` so any review-rendering widget can watch it and
/// filter blocked authors out instantly. [load] is called on sign-in and
/// [clear] on sign-out. State is the set of blocked user ids.
class BlockCubit extends Cubit<Set<String>> {
  final BlockUserUseCase _blockUser;
  final UnblockUserUseCase _unblockUser;
  final GetBlockedUserIdsUseCase _getBlockedIds;

  BlockCubit({
    required BlockUserUseCase blockUser,
    required UnblockUserUseCase unblockUser,
    required GetBlockedUserIdsUseCase getBlockedIds,
  }) : _blockUser = blockUser,
       _unblockUser = unblockUser,
       _getBlockedIds = getBlockedIds,
       super(const <String>{});

  bool isBlocked(String userId) => state.contains(userId);

  /// Loads the blocked-id set for the signed-in user. Safe to call repeatedly.
  Future<void> load() async {
    try {
      final ids = await _getBlockedIds();
      emit(ids);
    } catch (e) {
      debugPrint('BlockCubit.load failed: $e');
    }
  }

  /// Clears local state (call on sign-out).
  void clear() => emit(const <String>{});

  /// Blocks [userId] and updates the cache immediately so feeds refresh at once.
  /// Rethrows on failure so callers can surface an error and roll back UI.
  Future<void> block(String userId) async {
    await _blockUser(userId);
    emit({...state, userId});
  }

  /// Unblocks [userId] and updates the cache.
  Future<void> unblock(String userId) async {
    await _unblockUser(userId);
    final next = {...state}..remove(userId);
    emit(next);
  }
}
