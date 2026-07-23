import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:nook/core/analytics/analytics_config.dart';

/// Shared analytics property keys passed via `metadata` into PostHog events.
abstract final class AnalyticsMetadataKeys {
  static const screen = 'screen';
  static const mapApp = 'map_app';
  static const latitude = 'latitude';
  static const longitude = 'longitude';
}

/// Minimal cafe analytics: four core funnel events for owner-facing reporting.
///
/// **Core funnel (Superadmin / owner dashboard)**
/// - Awareness: [viewDetails]
/// - Intent: [checkHours]
/// - Conversion: [getDirections]
class AnalyticsService {
  AnalyticsService();

  /// `view_details` — user opened cafe details (awareness / brand interest).
  static const String viewDetails = 'view_details';

  /// `check_hours` — user expanded or engaged with hours / schedule (intent).
  static const String checkHours = 'check_hours';

  /// `get_directions` — user requested directions (lead / conversion).
  static const String getDirections = 'get_directions';

  /// Maps legacy Supabase event names to new PostHog event names.
  String _mapEventName(String eventType) {
    return switch (eventType) {
      viewDetails => 'cafe_detail_viewed',
      getDirections => 'directions_tapped',
      _ => eventType, // e.g. check_hours remains check_hours
    };
  }

  /// Refactored to use PostHog capture.
  ///
  /// Note: User identification should be handled in Auth logic via
  /// `Posthog().identify(userId: supabaseUserId)` when the user logs in.
  Future<void> track(
    String cafeId,
    String eventType, {
    Map<String, dynamic>? metadata,
  }) async {
    if (cafeId.isEmpty) return;

    final eventName = _mapEventName(eventType);
    final properties = <String, Object>{
      'cafe_id': cafeId,
      if (metadata != null) ...metadata,
    };

    if (!kAnalyticsEnabled) return;

    try {
      await Posthog().capture(eventName: eventName, properties: properties);
    } catch (e, st) {
      assert(() {
        debugPrint('PostHog tracking failed: $e\n$st');
        return true;
      }());
    }
  }

  Future<void> logEvent(
    String eventName, {
    Map<String, Object>? properties,
  }) async {
    if (eventName.isEmpty) return;

    if (!kAnalyticsEnabled) return;

    try {
      await Posthog().capture(eventName: eventName, properties: properties);
    } catch (e, st) {
      assert(() {
        debugPrint('PostHog event logging failed: $e\n$st');
        return true;
      }());
    }
  }
}
