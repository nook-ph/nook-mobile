import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Shared keys for [cafe_events.metadata] JSON.
abstract final class AnalyticsMetadataKeys {
  static const screen = 'screen';
  static const platform = 'platform';
  static const mapApp = 'map_app';
  static const latitude = 'latitude';
  static const longitude = 'longitude';
}

@visibleForTesting
Map<String, dynamic> mergeAnalyticsMetadata(Map<String, dynamic>? metadata) {
  final base = <String, dynamic>{
    AnalyticsMetadataKeys.platform: defaultTargetPlatform.name,
  };
  if (metadata != null && metadata.isNotEmpty) {
    base.addAll(metadata);
  }
  return base;
}

/// Minimal cafe analytics: four core funnel events for owner-facing reporting.
///
/// **Core funnel (Superadmin / owner dashboard)**
/// - Awareness: [viewDetails]
/// - Intent: [checkHours]
/// - Conversion: [getDirections]
/// - Loyalty: [saveToFavorites]
class AnalyticsService {
  AnalyticsService(this._client);

  final SupabaseClient _client;
  final String _sessionId = const Uuid().v4();

  String get sessionId => _sessionId;

  /// `view_details` — user opened cafe details (awareness / brand interest).
  static const String viewDetails = 'view_details';

  /// `check_hours` — user expanded or engaged with hours / schedule (intent).
  static const String checkHours = 'check_hours';

  /// `get_directions` — user requested directions (lead / conversion).
  static const String getDirections = 'get_directions';

  /// `save_to_favorites` — user saved the cafe (loyalty).
  static const String saveToFavorites = 'save_to_favorites';

  /// Persists an event. [cafeId] must be non-empty and must satisfy FK to [cafes].
  Future<void> track(
    String cafeId,
    String eventType, {
    Map<String, dynamic>? metadata,
  }) async {
    if (cafeId.isEmpty) return;

    final merged = mergeAnalyticsMetadata(metadata);

    try {
      await _client.from('cafe_events').insert({
        'cafe_id': cafeId,
        'event_type': eventType,
        'user_id': _client.auth.currentUser?.id,
        'session_id': _sessionId,
        'metadata': merged,
      });
    } catch (e, st) {
      assert(() {
        debugPrint('AnalyticsService.track failed: $e\n$st');
        return true;
      }());
    }
  }
}
