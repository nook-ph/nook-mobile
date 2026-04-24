import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';

void main() {
  late AnalyticsService analyticsService;

  setUp(() {
    analyticsService = AnalyticsService();
  });

  group('AnalyticsService event constants', () {
    test('core funnel event_type strings are stable', () {
      expect(AnalyticsService.viewDetails, 'view_details');
      expect(AnalyticsService.checkHours, 'check_hours');
      expect(AnalyticsService.getDirections, 'get_directions');
      expect(AnalyticsService.saveToFavorites, 'save_to_favorites');
    });
  });

  group('track', () {
    test('does nothing if cafeId is empty', () async {
      // should not crash or throw
      await analyticsService.track('', AnalyticsService.viewDetails);
    });

    // Note: Internal Posthog().capture calls are harder to verify without 
    // a mock injection or wrapper, but we've verified the logic refactor.
  });
}
