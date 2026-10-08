import 'package:nook/features/public_profile/domain/entities/public_profile.dart';

/// Public profiles (`get_public_profile`) and the owner's switch for what
/// they show (`profiles.show_profile_highlights`). Behind an interface so
/// the screens run against a fake in tests and in the debug demo.
abstract interface class IPublicProfileRepository {
  /// The profile for [username] or [userId] (one of them), as a visitor
  /// sees it. Null when there is no such profile, or it cannot be shown to
  /// this viewer (suspended, blocked either way): the screen says "not
  /// found" for all of these, on purpose.
  Future<PublicProfile?> getProfile({String? username, String? userId});

  /// Up to [limit] people whose username starts with [prefix] (no "@"),
  /// shortest first. Suspended and not-yet-active accounts are left out.
  Future<List<PersonMatch>> searchPeople(String prefix, {int limit = 5});

  /// Whether the signed-in person shows their gallery.
  Future<bool> getMyHighlightsPublic();

  Future<void> setMyHighlightsPublic(bool value);

  /// Reports someone else's photo (the image or its note) for review.
  /// Reporting the same photo twice is not an error.
  Future<void> reportPhoto(
    String photoId,
    PhotoReportReason reason, {
    String? details,
  });

  /// Reports someone else's profile (their name, avatar or bio) for review
  /// (`profile_reports`). Reporting the same person twice is not an error.
  Future<void> reportProfile(
    String userId,
    ProfileReportReason reason, {
    String? details,
  });
}

/// Why a photo was reported (`photo_reports.reason`).
enum PhotoReportReason {
  offensive('offensive', 'Offensive or hateful'),
  notCoffee('not_coffee', 'Not a drink or a cafe'),
  spam('spam', 'Spam or an ad'),
  other('other', 'Something else');

  const PhotoReportReason(this.wire, this.label);

  final String wire;
  final String label;
}

/// Why a profile was reported (`profile_reports.reason`).
enum ProfileReportReason {
  offensive('offensive', 'Offensive name, photo or bio'),
  spam('spam', 'Spam or a fake account'),
  impersonation('impersonation', 'Pretending to be someone else'),
  other('other', 'Something else');

  const ProfileReportReason(this.wire, this.label);

  final String wire;
  final String label;
}

/// Thrown when a public profile read or the switch write fails.
class PublicProfileException implements Exception {
  const PublicProfileException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'PublicProfileException: $message';
}
