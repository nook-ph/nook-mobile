import 'package:equatable/equatable.dart';
import 'package:nook/core/cafe/domain/entities/cafe_list.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';

/// How many of a person's places they have been to: "Been to 3 of 8".
///
/// Been and Want to Try are mutually exclusive per cafe, and marking a Want
/// to Try cafe Been moves it out of Want to Try (`set_cafe_status`,
/// nook-supabase/docs/BEEN_WANT_TO_TRY.md §1). So a person's places are the
/// two lists together, and the ones visited are the Been list:
/// `been of (been + wantToTry)`. Nothing records which Been cafes started on
/// Want to Try, so a cafe marked Been straight away counts as a place
/// visited too; the copy says "of your places", never "of your Want to Try".
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

  /// 0 to 1, for a progress bar. 0 when there is nothing saved.
  double get fraction => total == 0 ? 0 : been / total;

  /// "Been to 3 of 8", "Been to all 3"; null when nothing is saved (show
  /// nothing then).
  String? get label {
    if (isEmpty) return null;
    if (isComplete) return 'Been to all $total';
    return 'Been to $been of $total';
  }

  /// For screen readers, where "3 of 8" alone loses what is counted.
  String? get semanticsLabel {
    if (isEmpty) return null;
    final places = total == 1 ? 'place' : 'places';
    if (isComplete) return 'Been to all $total of your $places';
    return 'Been to $been of your $total $places';
  }

  @override
  List<Object?> get props => [been, wantToTry];
}
