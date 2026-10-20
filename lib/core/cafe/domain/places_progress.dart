import 'package:equatable/equatable.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';

/// How many of a person's places they have been to, and how many are left
/// to try: "3 been · 5 to try".
///
/// Been and Want to Try are mutually exclusive per cafe, and marking a Want
/// to Try cafe Been moves it out of Want to Try (`set_cafe_status`,
/// nook-supabase/docs/BEEN_WANT_TO_TRY.md §1). So a person's places are the
/// two lists together, and the ones visited are the Been list:
/// `been of (been + wantToTry)`. Nothing records which Been cafes started on
/// Want to Try, so a cafe marked Been straight away counts as a place
/// visited too, and the finished state says "All 3 been", never "Been to
/// all of your Want to Try".
class PlacesProgress extends Equatable {
  const PlacesProgress({required this.been, required this.wantToTry})
    : assert(been >= 0 && wantToTry >= 0);

  /// From a guest's on-phone statuses, one per cafe.
  factory PlacesProgress.fromStatuses(Iterable<CafeStatus> statuses) {
    var been = 0;
    var wantToTry = 0;
    for (final status in statuses) {
      switch (status) {
        case CafeStatus.been:
          been++;
        case CafeStatus.wantToTry:
          wantToTry++;
        case CafeStatus.none:
          break;
      }
    }
    return PlacesProgress(been: been, wantToTry: wantToTry);
  }

  /// From an account's lists: the Been and Want to Try system lists' counts.
  /// Custom lists are not places in this sense and are ignored.
  factory PlacesProgress.fromLists(Iterable<CafeList> lists) {
    var been = 0;
    var wantToTry = 0;
    for (final list in lists) {
      if (list.listType == CafeStatus.been.wire) been += list.cafeCount;
      if (list.listType == CafeStatus.wantToTry.wire) {
        wantToTry += list.cafeCount;
      }
    }
    return PlacesProgress(been: been, wantToTry: wantToTry);
  }

  final int been;
  final int wantToTry;

  int get total => been + wantToTry;

  bool get isEmpty => total == 0;

  bool get isComplete => total > 0 && wantToTry == 0;

  /// 0 to 1: the share of places that are Been. 0 when nothing is saved.
  double get fraction => total == 0 ? 0 : been / total;

  /// Two counts, never a ratio: a ratio falls each time a cafe is saved
  /// (1 of 3 becomes 1 of 4), and "Been to 0 of 3" counts a goal nobody
  /// set (UX research 2026-10-16, findings 4 and 5).
  ///
  /// - nothing Been yet: "3 to try";
  /// - some of each: "1 been · 2 to try";
  /// - nothing left to try: "All 3 been". Nothing records whether those
  ///   started on Want to Try, so this does not say "Been to all".
  ///
  /// Null when nothing is saved (show nothing then).
  String? get label {
    if (isEmpty) return null;
    if (been == 0) return '$wantToTry to try';
    if (wantToTry == 0) return 'All $been been';
    return '$been been · $wantToTry to try';
  }

  /// For screen readers: what is counted, in words.
  String? get semanticsLabel {
    if (isEmpty) return null;
    String cafes(int n) => n == 1 ? '1 cafe' : '$n cafes';
    if (been == 0) return '${cafes(wantToTry)} to try';
    if (wantToTry == 0) return 'All ${cafes(been)} been';
    return '${cafes(been)} been, $wantToTry to try';
  }

  @override
  List<Object?> get props => [been, wantToTry];
}
