import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

/// Where the "Which café?" sheet gets its rows. Behind an interface so the
/// sheet can be tested without Supabase or location services.
abstract interface class ICafePickerSource {
  /// The person's Been cafes, most recently added first.
  Future<List<CafeSummary>> beenCafes();

  /// Cafes near the device, nearest first. Null when location is off or not
  /// allowed (the sheet then offers to turn it on). Prompts for permission
  /// only when [ask] is true, which is a tap on "Use my location".
  Future<List<CafeSummary>?> nearby({bool ask = false});

  /// The cafe a photo was most likely taken at: the nearest within
  /// [maxMeters] of its EXIF position, or null.
  Future<CafeSummary?> takenAt(
    double lat,
    double lng, {
    double maxMeters = 150,
  });

  /// Cafes whose name, area or tags match [query].
  Future<List<CafeSummary>> search(String query);
}
