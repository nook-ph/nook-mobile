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
        SignUpAskRules.shouldAsk(scored(20), now: now, savesCount: 1),
        isTrue,
      );
    });

    test('not under 20', () {
      expect(
        SignUpAskRules.shouldAsk(scored(19.5), now: now, savesCount: 1),
        isFalse,
      );
    });

    test('never without saves: the ask is about keeping them', () {
      expect(
        SignUpAskRules.shouldAsk(scored(40), now: now, savesCount: 0),
        isFalse,
      );
    });

    test('at most once per 7 days', () {
      final asked = scored(30).asked(now);
      expect(
        SignUpAskRules.shouldAsk(
          asked,
          now: now.add(const Duration(days: 6, hours: 23)),
          savesCount: 1,
        ),
        isFalse,
      );
      expect(
        SignUpAskRules.shouldAsk(
          asked,
          now: now.add(const Duration(days: 7)),
          savesCount: 1,
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
          savesCount: 1,
        ),
        isFalse,
      );
    });

    test('a lower debug threshold is honoured', () {
      expect(
        SignUpAskRules.shouldAsk(
          scored(5),
          now: now,
          savesCount: 1,
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

    test('a declined ask comes back only 15 points later', () {
      // -5 off the score and +10 on the threshold.
      final s = scored(20).asked(now).dismissed();
      final later = now.add(const Duration(days: 8));
      expect(s.score, 15);
      expect(SignUpAskRules.thresholdFor(s), 30);
      expect(
        SignUpAskRules.blockedBy(s, now: later, savesCount: 1),
        SignUpAskBlock.belowThreshold,
      );
      expect(
        SignUpAskRules.shouldAsk(
          s.add(EngagementAction.search).add(EngagementAction.search),
          now: later,
          savesCount: 1,
        ),
        isFalse,
      );
      expect(
        SignUpAskRules.shouldAsk(
          s
              .add(EngagementAction.search)
              .add(EngagementAction.search)
              .add(EngagementAction.search),
          now: later,
          savesCount: 1,
        ),
        isTrue,
      );
    });
  });

  group('back-off', () {
    test('cooldown is 7 days after the first decline, 21 after the second', () {
      final once = scored(99).asked(now, savesCount: 4).dismissed();
      expect(SignUpAskRules.cooldownFor(once), const Duration(days: 7));
      expect(
        SignUpAskRules.shouldAsk(
          once,
          now: now.add(const Duration(days: 7)),
          savesCount: 4,
        ),
        isTrue,
      );

      final second = now.add(const Duration(days: 7));
      final twice = once.asked(second, savesCount: 4).dismissed();
      expect(SignUpAskRules.cooldownFor(twice), const Duration(days: 21));
      expect(
        SignUpAskRules.blockedBy(
          twice,
          now: second.add(const Duration(days: 20)),
          savesCount: 8,
        ),
        SignUpAskBlock.cooldown,
      );
      expect(
        SignUpAskRules.shouldAsk(
          twice,
          now: second.add(const Duration(days: 21)),
          savesCount: 8,
        ),
        isTrue,
      );
    });

    test('the threshold rises 10 per decline', () {
      var s = const EngagementState();
      expect(SignUpAskRules.thresholdFor(s), 20);
      s = s.dismissed();
      expect(SignUpAskRules.thresholdFor(s), 30);
      s = s.dismissed();
      expect(SignUpAskRules.thresholdFor(s), 40);
      expect(SignUpAskRules.thresholdFor(s, base: 5), 25);
    });

    test(
      'the third ask waits until the saves have doubled since the second',
      () {
        final twice = scored(99)
            .asked(now, savesCount: 3)
            .dismissed()
            .asked(now, savesCount: 5)
            .dismissed();
        final later = now.add(const Duration(days: 30));
        expect(
          SignUpAskRules.blockedBy(twice, now: later, savesCount: 9),
          SignUpAskBlock.savesNotDoubled,
        );
        expect(
          SignUpAskRules.shouldAsk(twice, now: later, savesCount: 10),
          isTrue,
        );
      },
    );

    test('"Keep using on this phone" ends score asks', () {
      final s = scored(99).asked(now).dismissed(stay: true);
      expect(s.stayOnPhone, isTrue);
      expect(
        SignUpAskRules.blockedBy(
          s,
          now: now.add(const Duration(days: 365)),
          savesCount: 50,
        ),
        SignUpAskBlock.stayOnPhone,
      );
    });
  });

  group('points once per cafe', () {
    test('a save earns 5 once; removing it takes them back', () {
      var s = const EngagementState().saved('a');
      expect(s.score, 5);
      s = s.saved('a');
      expect(s.score, 5);
      s = s.unsaved('a');
      expect(s.score, 0);
      // Save, Undo, save again: still one save's worth.
      s = s.saved('a').unsaved('a').saved('a');
      expect(s.score, 5);
      expect(s.saved('b').score, 10);
    });

    test('removing a cafe that earned nothing takes nothing', () {
      expect(scored(12).unsaved('x').score, 12);
    });

    test('survives a round trip through storage', () {
      final s = const EngagementState()
          .saved('a')
          .asked(now, savesCount: 3)
          .dismissed(stay: true);
      expect(EngagementState.fromJson(s.toJson()), s);
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
