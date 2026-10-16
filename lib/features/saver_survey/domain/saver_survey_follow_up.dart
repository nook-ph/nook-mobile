import 'dart:math' as math;

import 'package:nook/features/guest_saves/domain/cafe_snapshot.dart';
import 'package:nook/features/saver_survey/domain/saver_survey_reasons.dart';

/// The one card the survey sheet swaps to after Send. [wire] is the `kind`
/// analytics gets.
enum SaverSurveyFollowUpKind {
  /// "Not sure it's open": the named cafe's open state today.
  openState('open_state'),

  /// "Too far from me", with a position: the closest Want to Try.
  nearest('nearest'),

  /// "Too far from me", no position but location can still be asked for.
  locationAsk('location_ask'),

  /// "Waiting for a friend": share the cafe.
  share('share'),

  /// "Saving it for later": it stays in Your places.
  later('later');

  const SaverSurveyFollowUpKind(this.wire);
  final String wire;
}

/// What the follow-up card shows.
class SaverSurveyFollowUp {
  const SaverSurveyFollowUp(this.kind, {this.cafe, this.distanceMeters});

  final SaverSurveyFollowUpKind kind;

  /// The cafe on the card: the named one, or the nearest save. Null only for
  /// [SaverSurveyFollowUpKind.locationAsk] and [SaverSurveyFollowUpKind.later].
  final CafeSnapshot? cafe;

  /// From the phone's last position to [cafe]; [SaverSurveyFollowUpKind.nearest]
  /// only.
  final double? distanceMeters;
}

/// Picks the follow-up for an answer. Pure: everything it needs is passed in.
///
/// The reasons are tried in [priority] order, so with two picked the more
/// useful card wins; one that cannot be answered from the phone (no cafe
/// known, no position and no way to ask) falls through to the next. Null:
/// no card, the sheet closes with the thanks toast.
abstract final class SaverSurveyFollowUps {
  static const priority = [
    SaverSurveyCopy.unsureOpen,
    SaverSurveyCopy.tooFar,
    SaverSurveyCopy.waitingForFriend,
    SaverSurveyCopy.savingForLater,
  ];

  static SaverSurveyFollowUp? pick({
    required List<String> reasons,
    required CafeSnapshot? cafe,
    required List<CafeSnapshot> saves,
    required ({double lat, double lng})? position,
    required bool canAskLocation,
  }) {
    for (final reason in priority) {
      if (!reasons.contains(reason.id)) continue;
      final card = switch (reason.id) {
        'unsure_open' when cafe != null => SaverSurveyFollowUp(
          SaverSurveyFollowUpKind.openState,
          cafe: cafe,
        ),
        'too_far' => _far(saves, position, canAskLocation),
        'waiting_for_friend' when cafe != null => SaverSurveyFollowUp(
          SaverSurveyFollowUpKind.share,
          cafe: cafe,
        ),
        'saving_for_later' => const SaverSurveyFollowUp(
          SaverSurveyFollowUpKind.later,
        ),
        _ => null,
      };
      if (card != null) return card;
    }
    return null;
  }

  static SaverSurveyFollowUp? _far(
    List<CafeSnapshot> saves,
    ({double lat, double lng})? position,
    bool canAskLocation,
  ) {
    if (position == null) {
      return canAskLocation
          ? const SaverSurveyFollowUp(SaverSurveyFollowUpKind.locationAsk)
          : null;
    }
    return nearest(saves, position);
  }

  /// The closest of [saves] that has coordinates, or null when none does.
  static SaverSurveyFollowUp? nearest(
    List<CafeSnapshot> saves,
    ({double lat, double lng}) position,
  ) {
    CafeSnapshot? best;
    var bestMeters = double.infinity;
    for (final cafe in saves) {
      final lat = cafe.lat;
      final lng = cafe.lng;
      if (lat == null || lng == null) continue;
      final meters = distanceMeters(position.lat, position.lng, lat, lng);
      if (meters < bestMeters) {
        best = cafe;
        bestMeters = meters;
      }
    }
    if (best == null) return null;
    return SaverSurveyFollowUp(
      SaverSurveyFollowUpKind.nearest,
      cafe: best,
      distanceMeters: bestMeters,
    );
  }

  /// Great-circle distance in meters (haversine; what Geolocator uses).
  static double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earth = 6378137.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) *
            math.cos(rad(lat2)) *
            math.pow(math.sin(dLng / 2), 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
