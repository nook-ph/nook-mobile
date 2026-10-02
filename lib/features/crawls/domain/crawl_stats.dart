import 'package:nook/core/utils/geo.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';

/// The three numbers on the recap and share overlays, all derived from data
/// the run already carries (docs/COMMUNITY_CRAWLS.md §4.6.1).
class CrawlStats {
  const CrawlStats._();

  /// Sum of straight-line distances between consecutive stops — not a tracked
  /// walking path. Nothing here needs background location.
  static double routeDistanceMeters(List<CrawlStop> stops) {
    var total = 0.0;
    for (var i = 1; i < stops.length; i++) {
      total += haversineMeters(
        GeoPoint(lat: stops[i - 1].lat, lng: stops[i - 1].lng),
        GeoPoint(lat: stops[i].lat, lng: stops[i].lng),
      );
    }
    return total;
  }

  /// First stamp to last stamp, for the caller. Null with fewer than two.
  static Duration? elapsed(CrawlRun run) {
    final stamps = run.myStamps;
    if (stamps.length < 2) return null;
    return stamps.last.claimedAt.difference(stamps.first.claimedAt);
  }

  static String formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  /// "3:42 PM" — the app has no intl dependency, and this is the one place a
  /// clock time is shown.
  static String formatClock(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.hour < 12 ? 'AM' : 'PM'}';
  }
}
