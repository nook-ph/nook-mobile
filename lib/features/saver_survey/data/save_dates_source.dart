import 'package:flutter/foundation.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/features/guest_saves/presentation/cubit/guest_saves_cubit.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_rules.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// When the Want to Try / Been cafes were saved, for the saver survey.
abstract interface class SaveDatesSource {
  /// Null when they could not be read.
  Future<SaveDates?> read();
}

/// A guest's saves, kept on this phone.
class GuestSaveDatesSource implements SaveDatesSource {
  const GuestSaveDatesSource(this.cubit);

  final GuestSavesCubit cubit;

  @override
  Future<SaveDates?> read() async {
    await cubit.load();
    final state = cubit.state;
    if (!state.loaded) return null;
    return SaveDates(
      wantToTry: [
        for (final s in state.withStatus(CafeStatus.wantToTry)) s.savedAt,
      ],
      been: [for (final s in state.withStatus(CafeStatus.been)) s.savedAt],
    );
  }
}

/// A signed-in user's saves: `list_cafes.added_at` on their two system
/// lists. One read of `list_members` and one of `list_cafes`, the same rows
/// the Saved tab reads, so nothing new is asked of the server.
class AccountSaveDatesSource implements SaveDatesSource {
  AccountSaveDatesSource({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  @override
  Future<SaveDates?> read() async {
    try {
      final client = _client ?? Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;
      // Same path as the Saved tab's list read: owned memberships.
      final members = await client
          .from('list_members')
          .select('list_id, lists ( id, list_type )')
          .eq('user_id', userId)
          .eq('role', 'owner');
      final typeById = <String, String>{};
      for (final raw in members as List) {
        final list = raw is Map ? raw['lists'] : null;
        if (list is! Map || list['id'] is! String) continue;
        final type = '${list['list_type']}';
        if (type == 'want_to_try' || type == 'been') {
          typeById[list['id'] as String] = type;
        }
      }
      if (typeById.isEmpty) return const SaveDates();
      final rows = await client
          .from('list_cafes')
          .select('list_id, added_at')
          .inFilter('list_id', typeById.keys.toList());
      final wantToTry = <DateTime>[];
      final been = <DateTime>[];
      for (final raw in rows as List) {
        if (raw is! Map) continue;
        final at = DateTime.tryParse('${raw['added_at']}');
        if (at == null) continue;
        switch (typeById[raw['list_id']]) {
          case 'want_to_try':
            wantToTry.add(at);
          case 'been':
            been.add(at);
        }
      }
      return SaveDates(wantToTry: wantToTry, been: been);
    } catch (e) {
      debugPrint('[SaverSurvey] account saves read failed: $e');
      return null;
    }
  }
}
