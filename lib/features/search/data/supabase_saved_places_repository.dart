import 'package:nook/features/search/domain/entities/saved_place.dart';
import 'package:nook/features/search/domain/repositories/i_saved_places_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `saved_places` table. RLS limits every row to its owner; the
/// queries filter by the owner as well so a policy mistake still returns
/// only this user's places.
class SupabaseSavedPlacesRepository implements ISavedPlacesRepository {
  SupabaseSavedPlacesRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'saved_places';
  static const _columns = 'id, kind, label, address, lat, lng';

  String? get _uid => _client.auth.currentUser?.id;

  @override
  bool get canSave => _uid != null;

  @override
  Future<List<SavedPlace>> list() async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _client
        .from(_table)
        .select(_columns)
        .eq('user_id', uid)
        .order('created_at');
    return rows.map(SavedPlace.fromJson).whereType<SavedPlace>().toList();
  }

  @override
  Future<SavedPlace> save(SavedPlace place) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to save places.');
    final values = {
      'kind': place.kind.name,
      'label': place.label.trim(),
      'address': place.address,
      'lat': place.lat,
      'lng': place.lng,
    };
    try {
      final id = place.id;
      final row = id == null
          ? await _client
                .from(_table)
                .insert({...values, 'user_id': uid})
                .select(_columns)
                .single()
          : await _client
                .from(_table)
                .update(values)
                .eq('id', id)
                .eq('user_id', uid)
                .select(_columns)
                .single();
      return SavedPlace.fromJson(row) ?? place;
    } on PostgrestException catch (e) {
      if (e.message.contains('saved_places_limit_reached')) {
        throw const SavedPlacesLimitReached();
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _client.from(_table).delete().eq('id', id).eq('user_id', uid);
  }
}
