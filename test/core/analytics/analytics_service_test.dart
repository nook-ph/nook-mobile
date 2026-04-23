import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/analytics/analytics_service.dart';

void main() {
  group('mergeAnalyticsMetadata', () {
    test('includes platform and merges user metadata', () {
      final merged = mergeAnalyticsMetadata({
        AnalyticsMetadataKeys.screen: 'cafe_details',
        'custom': 1,
      });

      expect(merged[AnalyticsMetadataKeys.platform], isNotNull);
      expect(merged[AnalyticsMetadataKeys.screen], 'cafe_details');
      expect(merged['custom'], 1);
    });

    test('user metadata can override platform key', () {
      final merged = mergeAnalyticsMetadata({
        AnalyticsMetadataKeys.platform: 'should_be_overwritten',
      });

      expect(merged[AnalyticsMetadataKeys.platform], 'should_be_overwritten');
    });

    test('null or empty metadata yields platform only', () {
      expect(mergeAnalyticsMetadata(null).keys, contains('platform'));
      expect(mergeAnalyticsMetadata({}).keys, contains('platform'));
    });
  });

  group('AnalyticsService event constants', () {
    test('core funnel event_type strings are stable', () {
      expect(AnalyticsService.viewDetails, 'view_details');
      expect(AnalyticsService.checkHours, 'check_hours');
      expect(AnalyticsService.getDirections, 'get_directions');
      expect(AnalyticsService.saveToFavorites, 'save_to_favorites');
    });
  });
}
