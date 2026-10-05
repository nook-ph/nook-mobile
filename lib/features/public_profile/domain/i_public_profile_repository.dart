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

  /// Whether the signed-in person shows their top cafes and gallery.
  Future<bool> getMyHighlightsPublic();

  Future<void> setMyHighlightsPublic(bool value);
}

/// Thrown when a public profile read or the switch write fails.
class PublicProfileException implements Exception {
  const PublicProfileException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'PublicProfileException: $message';
}
