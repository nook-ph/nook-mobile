import 'package:nook/core/cafe/domain/entities/report_reason.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';

/// Which backend the cups run on. [cups] once the Cups RPCs answered,
/// [legacy] once they turned out not to exist (the migrations are not
/// applied), [unknown] until the first call says which.
enum CupsMode { unknown, cups, legacy }

/// Cups: one card per visit, merging reviews and the coffee gallery.
///
/// Every call works on both backends: the Cups RPCs when they exist, else
/// the reviews and gallery reads and writes the app used before (the
/// legacy-safe rule, nook-supabase docs/CUPS_APPLY.md). Throws
/// [CupsException] on failure.
abstract interface class ICupsRepository {
  CupsMode get mode;

  /// Settles [mode] if nobody has asked the server yet.
  Future<CupsMode> resolveMode();

  /// A page of [cafeId]'s cups with the section numbers.
  Future<CafeCups> getCafeCups(
    String cafeId, {
    CupSort sort = CupSort.recommended,
    int? ratingFilter,
    CupItemKind? kind,
    int limit = 10,
    int offset = 0,
  });

  /// A person's cups grouped by cafe, by [userId] or [username]. Null when
  /// the profile can't be shown (suspended, blocked, gone).
  Future<ProfileCups?> getProfileCups({String? userId, String? username});

  /// A new cup for this visit at [cafeId]. [onPhotoUploaded] is called with
  /// each photo item's index (in [items]) as its upload finishes.
  Future<CupPostResult> postCup({
    required String cafeId,
    int? rating,
    String? note,
    DateTime? visitedAt,
    required List<CupItemDraft> items,
    void Function(int index)? onPhotoUploaded,
  });

  /// Edits [cup] (yours): stars, note and date set as given (null clears
  /// stars and note), [addItems] added and [removeItemIds] removed.
  Future<CupPostResult> updateCup(
    CupCard cup, {
    int? rating,
    String? note,
    DateTime? visitedAt,
    List<CupItemDraft> addItems = const [],
    List<String> removeItemIds = const [],
    void Function(int index)? onPhotoUploaded,
  });

  /// Deletes [cup] (yours) and its photos.
  Future<void> deleteCup(CupCard cup);

  /// Helpful on someone else's cup. Returns the card as it is now.
  Future<CupCard> toggleHelpful(CupCard card);

  /// Reports someone else's cup: the cup, else its review, else each of
  /// its photos.
  Future<void> reportCup(
    CupCard card, {
    required String cafeId,
    required ReportReason reason,
    String? details,
  });
}

/// A cups read or write failed. [code] is the server's error message for
/// the cup RPCs (`cup_empty`, `note_too_long`, ...) when there was one.
class CupsException implements Exception {
  const CupsException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() => 'CupsException($code): $message';
}
