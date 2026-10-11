import 'package:nook/core/utils/content_filter.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';

/// What stops a cup from being posted, in the order the composer checks.
enum CupDraftIssue {
  /// No photo and no note: stars alone, or with only named items, are not
  /// a cup (the server refuses it as `cup_empty`).
  empty,
  tooManyItems,
  noteTooLong,

  /// The legacy backend stores a note as a 1.1.x review, which needs stars.
  needsRating,
  objectionable,
}

/// Checks a cup before it is posted. Null when it can go.
///
/// A cup needs a photo or a note; named items ("Banana bread") ride along
/// but don't count on their own, as on the server. Stars are optional. [legacy] is the fallback backend, where
/// a note is saved as a review and so needs a rating.
CupDraftIssue? checkCupDraft({
  required int photoCount,
  int namedItemCount = 0,
  required String note,
  required int? rating,
  List<String> itemNames = const [],
  bool legacy = false,
}) {
  final text = note.trim();
  if (photoCount <= 0 && text.isEmpty) {
    return CupDraftIssue.empty;
  }
  if (photoCount + namedItemCount > maxCupItems) {
    return CupDraftIssue.tooManyItems;
  }
  if (text.runes.length > maxCupNote) return CupDraftIssue.noteTooLong;
  if (legacy && text.isNotEmpty && rating == null) {
    return CupDraftIssue.needsRating;
  }
  if (ContentFilter.containsObjectionable(text) ||
      itemNames.any(ContentFilter.containsObjectionable)) {
    return CupDraftIssue.objectionable;
  }
  return null;
}

/// What the composer says about [issue].
String cupDraftMessage(CupDraftIssue issue) => switch (issue) {
  CupDraftIssue.empty => 'Add a photo or a note.',
  CupDraftIssue.tooManyItems => 'A cup holds up to $maxCupItems items.',
  CupDraftIssue.noteTooLong =>
    'Keep the note to $maxCupNote characters or fewer.',
  CupDraftIssue.needsRating => 'Add a star rating to post your note.',
  CupDraftIssue.objectionable => ContentFilter.rejectionMessage,
};

/// The server's reason for refusing a cup, in words. Null for an error
/// with no cup code, where the caller's own message stands.
String? cupErrorMessage(String? code) => switch (code) {
  'cup_empty' => cupDraftMessage(CupDraftIssue.empty),
  'too_many_items' ||
  'too_many_photos' => cupDraftMessage(CupDraftIssue.tooManyItems),
  'note_too_long' => cupDraftMessage(CupDraftIssue.noteTooLong),
  'legacy_needs_rating' => cupDraftMessage(CupDraftIssue.needsRating),
  'invalid_rating' => 'Pick between 1 and 5 stars, or none.',
  'email_not_verified' => 'Verify your email to post cups.',
  'not_authenticated' => 'Sign in to add your cup.',
  'cup_removed' => 'This cup was removed by Nook and can’t be edited.',
  'cup_not_found' => 'This cup is gone. Pull to refresh.',
  'cafe_not_found' => 'This cafe is no longer on Nook.',
  'invalid_item' ||
  'invalid_items' ||
  'invalid_photo' ||
  'invalid_photos' => 'A photo didn’t upload right. Remove it and try again.',
  _ => null,
};
