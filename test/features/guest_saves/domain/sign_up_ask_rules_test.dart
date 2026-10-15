import 'package:flutter_test/flutter_test.dart';
import 'package:nook/features/guest_saves/domain/sign_up_ask_rules.dart';

void main() {
  final now = DateTime.utc(2026, 10, 16, 12);

  EngagementState scored(double score) => EngagementState(score: score);

  group('weights (Pinterest starting values)', () {
    test('save, search, directions 5; cafe view 0.5; return session 5', () {
      expect(EngagementAction.save.weight, 5);
      expect(EngagementAction.search.weight, 5);
      expect(EngagementAction.directions.weight, 5);
      expect(EngagementAction.cafeView.weight, 0.5);
      expect(EngagementAction.returnSession.weight, 5);
    });

    test('two saves, a search, a directions tap and two views make 21', () {
      var s = const EngagementState();
      for (final a in [
        EngagementAction.save,
        EngagementAction.save,
        EngagementAction.search,
        EngagementAction.directions,
        EngagementAction.cafeView,
        EngagementAction.cafeView,
      ]) {
        s = s.add(a);
      }
      expect(s.score, 21);
    });
  });

  group('shouldAsk', () {
    test('at 20 with saves', () {
      expect(
        SignUpAskRules.shouldAsk(scored(20), now: now, hasSaves: true),
        isTrue,
      );
    });

    test('not under 20', () {
      expect(
        SignUpAskRules.shouldAsk(scored(19.5), now: now, hasSaves: true),
        isFalse,
      );
    });

    test('never without saves: the ask is about keeping them', () {
      expect(
        SignUpAskRules.shouldAsk(scored(40), now: now, hasSaves: false),
        isFalse,
      );
    });

    test('at most once per 7 days', () {
      final asked = scored(30).asked(now);
      expect(
        SignUpAskRules.shouldAsk(
          asked,
          now: now.add(const Duration(days: 6, hours: 23)),
          hasSaves: true,
        ),
        isFalse,
      );
      expect(
        SignUpAskRules.shouldAsk(
          asked,
          now: now.add(const Duration(days: 7)),
          hasSaves: true,
        ),
        isTrue,
      );
    });

    test('three asks at most', () {
      final s = scored(99).asked(now).asked(now).asked(now);
      expect(s.asks, 3);
      expect(
        SignUpAskRules.shouldAsk(
          s,
          now: now.add(const Duration(days: 365)),
          hasSaves: true,
        ),
        isFalse,
      );
    });

    test('a lower debug threshold is honoured', () {
      expect(
        SignUpAskRules.shouldAsk(
          scored(5),
          now: now,
          hasSaves: true,
          threshold: 5,
        ),
        isTrue,
      );
    });
  });

  group('dismissal', () {
    test('takes 5 off', () {
      expect(scored(22).dismissed().score, 17);
    });

    test('never below 0', () {
      expect(scored(3).dismissed().score, 0);
    });

    test('a dismissed ask needs 5 more points to come back', () {
      final s = scored(20).asked(now).dismissed();
      final later = now.add(const Duration(days: 8));
      expect(SignUpAskRules.shouldAsk(s, now: later, hasSaves: true), isFalse);
      expect(
        SignUpAskRules.shouldAsk(
          s.add(EngagementAction.save),
          now: later,
          hasSaves: true,
        ),
        isTrue,
      );
    });
  });

  group('sessions', () {
    test('the first session adds nothing', () {
      final s = const EngagementState().session(now);
      expect(s.score, 0);
      expect(s.lastSessionAt, now);
    });

    test('a second session within 30 days adds 5, once', () {
      final first = const EngagementState().session(now);
      final second = first.session(now.add(const Duration(days: 3)));
      expect(second.score, 5);
      expect(second.returnCounted, isTrue);
      final third = second.session(now.add(const Duration(days: 4)));
      expect(third.score, 5);
    });

    test('not after 30 days', () {
      final first = const EngagementState().session(now);
      final late = first.session(now.add(const Duration(days: 31)));
      expect(late.score, 0);
      expect(late.returnCounted, isFalse);
    });

    test('a quick switch back is not a new session', () {
      final first = const EngagementState().session(now);
      final quick = first.session(now.add(const Duration(minutes: 10)));
      expect(quick.score, 0);
    });
  });

  test('survives a round trip through JSON', () {
    final s = scored(
      12.5,
    ).asked(now).session(now).copyWith(returnCounted: true);
    expect(EngagementState.fromJson(s.toJson()), s);
    expect(EngagementState.fromJson('garbage'), const EngagementState());
  });
}
