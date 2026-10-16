import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';

/// The signed-in user's Want to Try cafes, newest first, for Home's "Your
/// places" row. Read from the Want to Try system list; a failed read keeps
/// what was there (the row is a convenience, not a source of truth).
class AccountWantToTryCubit extends Cubit<List<CafeSummary>> {
  AccountWantToTryCubit({required ICafeRepository repository})
    : _repository = repository,
      super(const []);

  final ICafeRepository _repository;
  int _generation = 0;

  /// [lists] are the user's lists when already in hand (`ListsBloc`), saving
  /// a read.
  Future<void> load({List<CafeList>? lists}) async {
    final generation = ++_generation;
    try {
      final all = lists ?? await _repository.getUserLists();
      final wantToTry = all
          .where((l) => l.listType == 'want_to_try')
          .firstOrNull;
      // A new list, never the const one clear() emitted: Cubit drops an
      // identical state, and readers wait for this load to land.
      final cafes = wantToTry == null
          ? <CafeSummary>[]
          : await _repository.getListCafes(wantToTry.id);
      if (isClosed || generation != _generation) return;
      emit(cafes);
    } catch (e) {
      debugPrint('[AccountWantToTry] load failed: $e');
    }
  }

  /// Signed out: nothing of the account stays on Home.
  void clear() {
    _generation++;
    emit(const []);
  }
}
