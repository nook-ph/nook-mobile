import 'package:flutter_test/flutter_test.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/ranking_session.dart';

RankingSession sessionOver(int n, {int cap = 4}) => RankingSession(
  cafeId: 'target',
  bucket: RankBucket.liked,
  opponents: List.generate(n, (i) => 'c${i + 1}'),
  maxComparisons: cap,
);

/// Runs a whole session against a known "true" position: the target belongs
/// directly above opponent index [trueIndex] (0-based), i.e. it beats every
/// opponent from that index on and loses to everything above.
int placeAt(int n, int trueIndex, {int cap = 4}) {
  final s = sessionOver(n, cap: cap);
  while (!s.isComplete) {
    final opponent = s.currentOpponent!;
    final opponentIndex = int.parse(opponent.substring(1)) - 1;
    s.answer(preferredTarget: opponentIndex >= trueIndex);
  }
  return s.resolvedPosition;
}

void main() {
  group('empty and trivial lists', () {
    test('first cafe in a bucket asks nothing and lands at 1', () {
      final s = sessionOver(0);
      expect(s.isComplete, isTrue);
      expect(s.currentOpponent, isNull);
      expect(s.resolvedPosition, 1);
      expect(s.comparisonsAsked, 0);
    });

    test('one opponent: winning takes the top slot', () {
      final s = sessionOver(1);
      expect(s.currentOpponent, 'c1');
      s.answer(preferredTarget: true);
      expect(s.isComplete, isTrue);
      expect(s.resolvedPosition, 1);
    });

    test('one opponent: losing lands below it', () {
      final s = sessionOver(1);
      s.answer(preferredTarget: false);
      expect(s.resolvedPosition, 2);
    });
  });

  group('binary search finds the exact slot', () {
    test('every position in a 7-cafe bucket', () {
      // 7 opponents → 8 possible landing slots, all reachable within the cap.
      for (var trueIndex = 0; trueIndex <= 7; trueIndex++) {
        expect(
          placeAt(7, trueIndex),
          trueIndex + 1,
          reason: 'target belonging above opponent #${trueIndex + 1}',
        );
      }
    });

    test('needs at most ceil(log2(n+1)) questions', () {
      // 15 opponents → 4 questions, exactly the cap.
      for (var trueIndex = 0; trueIndex <= 15; trueIndex++) {
        final s = sessionOver(15);
        while (!s.isComplete) {
          final i = int.parse(s.currentOpponent!.substring(1)) - 1;
          s.answer(preferredTarget: i >= trueIndex);
        }
        expect(s.comparisonsAsked, lessThanOrEqualTo(4));
        expect(s.resolvedPosition, trueIndex + 1);
      }
    });

    test('a run of wins puts it first, a run of losses puts it last', () {
      expect(placeAt(7, 0), 1);
      expect(placeAt(7, 7), 8);
    });
  });

  group('the cap keeps the flow short', () {
    test('stops asking at maxComparisons even when the range is open', () {
      // 100 opponents would need 7 questions; the cap allows 4.
      final s = sessionOver(100);
      var asked = 0;
      while (!s.isComplete) {
        s.answer(preferredTarget: false);
        asked++;
      }
      expect(asked, 4);
      expect(s.isComplete, isTrue);
      expect(s.currentOpponent, isNull);
      // Still a sane slot, just not necessarily the exact one.
      expect(s.resolvedPosition, greaterThan(1));
      expect(s.resolvedPosition, lessThanOrEqualTo(101));
    });

    test('a lower cap trades precision for fewer questions, not correctness', () {
      final s = sessionOver(7, cap: 1);
      s.answer(preferredTarget: true);
      expect(s.isComplete, isTrue);
      // One "better than the midpoint" answer rules out the bottom half.
      expect(s.resolvedPosition, inInclusiveRange(1, 4));
    });
  });

  group('skip', () {
    test('keeps the current best estimate and asks nothing more', () {
      final s = sessionOver(7);
      s.answer(preferredTarget: false); // worse than #4 → lower half
      final estimate = s.resolvedPosition;
      s.skip();
      expect(s.isComplete, isTrue);
      expect(s.currentOpponent, isNull);
      expect(s.resolvedPosition, estimate);
    });

    test('skipping immediately lands at the top of the bucket', () {
      final s = sessionOver(7);
      s.skip();
      expect(s.resolvedPosition, 1);
    });
  });

  group('robustness', () {
    test('answers after completion are ignored', () {
      final s = sessionOver(1);
      s.answer(preferredTarget: true);
      final settled = s.resolvedPosition;
      s.answer(preferredTarget: false);
      s.answer(preferredTarget: false);
      expect(s.resolvedPosition, settled);
      expect(s.comparisonsAsked, 1);
    });

    test('resolvedPosition is always a valid insertion slot mid-flight', () {
      final s = sessionOver(15);
      expect(s.resolvedPosition, inInclusiveRange(1, 16));
      s.answer(preferredTarget: false);
      expect(s.resolvedPosition, inInclusiveRange(1, 16));
      s.answer(preferredTarget: true);
      expect(s.resolvedPosition, inInclusiveRange(1, 16));
    });

    test('the opponent list is not mutated', () {
      final opponents = ['a', 'b', 'c'];
      final s = RankingSession(
        cafeId: 'target',
        bucket: RankBucket.fine,
        opponents: opponents,
      );
      while (!s.isComplete) {
        s.answer(preferredTarget: true);
      }
      expect(opponents, ['a', 'b', 'c']);
    });
  });
}
