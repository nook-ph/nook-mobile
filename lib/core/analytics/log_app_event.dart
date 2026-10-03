import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/injection_container.dart';

/// Logs a product event through [AnalyticsService], or does nothing where it
/// is not registered (widget tests that build one screen). Fire and forget.
void logAppEvent(String name, {Map<String, Object>? properties}) {
  if (!sl.isRegistered<AnalyticsService>()) return;
  sl<AnalyticsService>().logEvent(name, properties: properties);
}
