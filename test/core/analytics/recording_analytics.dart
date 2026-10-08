import 'package:get_it/get_it.dart';
import 'package:nook/core/analytics/analytics_service.dart';

/// Records what `logAppEvent` sends instead of sending it.
class RecordingAnalytics extends AnalyticsService {
  final List<(String, Map<String, Object>?)> events = [];

  List<String> get names => [for (final e in events) e.$1];

  Map<String, Object>? propertiesOf(String name) =>
      events.lastWhere((e) => e.$1 == name).$2;

  @override
  Future<void> logEvent(
    String eventName, {
    Map<String, Object>? properties,
  }) async => events.add((eventName, properties));

  /// Registers a fresh one with get_it for the test, and removes it after.
  static RecordingAnalytics install(
    void Function(void Function()) addTearDown,
  ) {
    final analytics = RecordingAnalytics();
    final sl = GetIt.instance;
    if (sl.isRegistered<AnalyticsService>()) {
      sl.unregister<AnalyticsService>();
    }
    sl.registerSingleton<AnalyticsService>(analytics);
    addTearDown(() {
      if (sl.isRegistered<AnalyticsService>()) {
        sl.unregister<AnalyticsService>();
      }
    });
    return analytics;
  }
}
