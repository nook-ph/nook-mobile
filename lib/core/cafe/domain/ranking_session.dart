import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';

/// Drives the head-to-head comparisons that place one cafe inside its bucket.
///
/// This is a binary-search insertion, not Elo (spec §1.2): the opponents are
/// already ordered, so each answer halves the remaining range and the position
/// is exact after ⌈log₂(n+1)⌉ questions — at a realistic 20 ranked cafes that
/// is 5, capped here at [maxComparisons]. Elo would need many redundant
/// matchups to converge on the same answer, which is fatigue by design.
///
/// Pure and synchronous: no repository, no cafe models, just ids. The UI
/// resolves ids to names and photos; the cubit persists the result. That keeps
/// the ordering logic unit-testable on its own.
class RankingSession {
  RankingSession({
    required this.cafeId,
    required this.bucket,
    required List<String> opponents,
    this.maxComparisons = 4,
  }) : _opponents = List.unmodifiable(opponents),
       _lo = 1,
       _hi = opponents.length;

  /// The cafe being placed.
  final String cafeId;

  /// The band it was bucketed into; comparisons only order within it.
  final RankBucket bucket;

  /// Hard ceiling on questions asked. Beli's own top complaint is that
  /// ranking gets "tedious", so the flow stops early and inserts at its
  /// current best estimate rather than always pinning the exact slot.
  final int maxComparisons;

  /// Cafe ids already ranked in [bucket], best first (position 1..n),
  /// excluding [cafeId] itself.
  final List<String> _opponents;

  int _lo;
  int _hi;
  int _asked = 0;
  bool _stopped = false;

  int get comparisonsAsked => _asked;

  /// True once the position is settled — the range collapsed, the cap was
  /// reached, the user skipped, or there was nothing to compare against.
  bool get isComplete => _stopped || _lo > _hi || _asked >= maxComparisons;

  /// The cafe to compare [cafeId] against, or null when [isComplete].
  String? get currentOpponent {
    if (isComplete) return null;
    return _opponents[_midpoint - 1];
  }

  /// 1-based insertion position within the bucket. Meaningful at any time —
  /// before completion it is the current best estimate, which is exactly what
  /// a skip should persist.
  int get resolvedPosition => _lo;

  /// Records one answer. [preferredTarget] is true when the user picked the
  /// cafe being ranked over [currentOpponent].
  void answer({required bool preferredTarget}) {
    if (isComplete) return;
    final mid = _midpoint;
    if (preferredTarget) {
      // Better than the midpoint → it belongs somewhere above it.
      _hi = mid - 1;
    } else {
      _lo = mid + 1;
    }
    _asked++;
  }

  /// "Too close to call" — keep the estimate, ask nothing further.
  void skip() => _stopped = true;

  int get _midpoint => (_lo + _hi) ~/ 2;
}
