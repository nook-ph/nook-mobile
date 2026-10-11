import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where a cafe's listing came from and whether anyone has checked it.
@immutable
class CafeListingStatus {
  const CafeListingStatus({required this.isImported, required this.isVerified});

  /// Added from public sources (the Google Places import), not by its owner
  /// or the Nook team.
  final bool isImported;

  /// Claimed by its owner, or checked by the Nook team.
  final bool isVerified;

  /// Imported and nobody has checked it yet: the "Unverified listing" note.
  bool get isUnverified => isImported && !isVerified;

  factory CafeListingStatus.fromJson(Map<String, dynamic> json) =>
      CafeListingStatus(
        isImported: json['is_imported'] == true,
        isVerified: json['is_verified'] == true,
      );
}

/// Reads `get_cafe_listing_status`, one cafe at a time, cached for the
/// session.
///
/// Every failure, including the function not existing yet on the server,
/// reads as "no status": the apps show no badge rather than an error, so this
/// can ship before the migration is applied.
class CafeListingStatusSource {
  CafeListingStatusSource(this._client);

  final SupabaseClient _client;
  final Map<String, Future<CafeListingStatus?>> _cache = {};

  Future<CafeListingStatus?> statusOf(String cafeId) {
    if (cafeId.isEmpty) return Future.value(null);
    return _cache.putIfAbsent(cafeId, () => _fetch(cafeId));
  }

  /// Forget [cafeId], e.g. after its owner claimed it.
  void invalidate(String cafeId) => _cache.remove(cafeId);

  Future<CafeListingStatus?> _fetch(String cafeId) async {
    try {
      final rows = await _client.rpc(
        'get_cafe_listing_status',
        params: {
          'p_cafe_ids': [cafeId],
        },
      );
      if (rows is! List || rows.isEmpty) return null;
      final row = rows.first;
      if (row is! Map) return null;
      return CafeListingStatus.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      // PGRST202: the function isn't on the server yet. Remember that for the
      // session instead of asking again on every cafe.
      if (error.code != 'PGRST202') _cache.remove(cafeId);
      debugPrint('get_cafe_listing_status unavailable: ${error.message}');
      return null;
    } catch (error) {
      // A network blip: drop it so the next visit retries.
      _cache.remove(cafeId);
      debugPrint('get_cafe_listing_status unavailable: $error');
      return null;
    }
  }
}
