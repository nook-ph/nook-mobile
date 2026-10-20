import 'package:equatable/equatable.dart';

/// What a guest did that counts toward asking them to sign in. Weights are
/// Pinterest web's starting values (teardowns brief, section 1).
enum EngagementAction {
  /// Counted once per cafe: removing the save (or undoing it) takes the
  /// points back ([EngagementState.saved], [EngagementState.unsaved]).
  save(5),
  search(5),
  directions(5),
  cafeView(0.5),

  /// A second session within [SignUpAskRules.returnWindow] of the last one;
  /// counted once.
  returnSession(5);

  const EngagementAction(this.weight);

  final double weight;
}

/// Why an ask that could have shown did not, for `signup_ask_suppressed`.
abstract final class SignUpAskBlock {
  static const noSaves = 'no_saves';
  static const belowThreshold = 'below_threshold';
  static const cooldown = 'cooldown';
  static const maxAsks = 'max_asks';

  /// The third ask waits until the saves have doubled since the second.
  static const savesNotDoubled = 'saves_not_doubled';

  /// "Keep using on this phone" was chosen: no more score asks.
  static const stayOnPhone = 'stay_on_phone';

  /// Something already asked this session ([SessionAskBudget]).
  static const sessionBudget = 'session_budget';
}

/// When the soft "keep your saves" ask may show. The ask can always be
/// dismissed; saves stay unlimited either way.
///
/// Each decline backs off further (ux finding 4): the threshold rises by
/// [declineThresholdStep], the cooldown is [cooldown] after the first decline
/// and [longCooldown] after the second, and the third ask comes only once the
/// saves have doubled since the second.
abstract final class SignUpAskRules {
  /// Asked at or above this score (before any decline).
  static const threshold = 20.0;

  /// Each dismissal takes this off the score.
  static const dismissPenalty = 5.0;

  /// Each decline raises the threshold by this much.
  static const declineThresholdStep = 10.0;

  /// The wait after an ask, and after the first decline.
  static const cooldown = Duration(days: 7);

  /// The wait after the second decline.
  static const longCooldown = Duration(days: 21);

  /// Never more than this many asks on one phone.
  static const maxAsks = 3;

  /// A session after this long away counts as a return...
  static const sessionGap = Duration(minutes: 30);

  /// ...when it comes within this long of the last session.
  static const returnWindow = Duration(days: 30);

  /// The score [state] needs, given its declines.
  static double thresholdFor(
    EngagementState state, {
    double base = SignUpAskRules.threshold,
  }) => base + declineThresholdStep * state.declines;

  /// The wait after the last ask, given the declines so far.
  static Duration cooldownFor(EngagementState state) =>
      state.declines >= 2 ? longCooldown : cooldown;

  /// Why the ask would not show now ([SignUpAskBlock]), or null when it
  /// would. [savesCount]: the ask is about keeping saves, so a guest with
  /// nothing saved is never asked.
  static String? blockedBy(
    EngagementState state, {
    required DateTime now,
    required int savesCount,
    double threshold = SignUpAskRules.threshold,
  }) {
    if (savesCount <= 0) return SignUpAskBlock.noSaves;
    if (state.stayOnPhone) return SignUpAskBlock.stayOnPhone;
    if (state.asks >= maxAsks) return SignUpAskBlock.maxAsks;
    final last = state.lastAskAt;
    if (last != null && now.difference(last) < cooldownFor(state)) {
      return SignUpAskBlock.cooldown;
    }
    if (state.score < thresholdFor(state, base: threshold)) {
      return SignUpAskBlock.belowThreshold;
    }
    if (state.asks >= 2 && savesCount < 2 * state.savesAtLastAsk) {
      return SignUpAskBlock.savesNotDoubled;
    }
    return null;
  }

  /// Whether to ask now; see [blockedBy].
  static bool shouldAsk(
    EngagementState state, {
    required DateTime now,
    required int savesCount,
    double threshold = SignUpAskRules.threshold,
  }) =>
      blockedBy(
        state,
        now: now,
        savesCount: savesCount,
        threshold: threshold,
      ) ==
      null;
}

/// The guest's engagement, kept on the phone.
class EngagementState extends Equatable {
  const EngagementState({
    this.score = 0,
    this.asks = 0,
    this.lastAskAt,
    this.lastSessionAt,
    this.returnCounted = false,
    this.declines = 0,
    this.savesAtLastAsk = 0,
    this.stayOnPhone = false,
    this.scoredCafes = const {},
  });

  final double score;

  /// How many times the ask has been shown.
  final int asks;
  final DateTime? lastAskAt;

  /// When the last session started.
  final DateTime? lastSessionAt;

  /// The return-session points have been given.
  final bool returnCounted;

  /// How many asks ended without a sign-in.
  final int declines;

  /// The guest's save count when the last ask showed.
  final int savesAtLastAsk;

  /// "Keep using on this phone" was chosen: no more score asks.
  final bool stayOnPhone;

  /// Cafes whose save has earned its points, so a save counts once per cafe.
  final Set<String> scoredCafes;

  EngagementState add(EngagementAction action) =>
      copyWith(score: score + action.weight);

  /// [cafeId] was saved: its points, once.
  EngagementState saved(String cafeId) {
    if (scoredCafes.contains(cafeId)) return this;
    return copyWith(
      score: score + EngagementAction.save.weight,
      scoredCafes: {...scoredCafes, cafeId},
    );
  }

  /// [cafeId]'s save was removed or undone: its points go back.
  EngagementState unsaved(String cafeId) {
    if (!scoredCafes.contains(cafeId)) return this;
    final lowered = score - EngagementAction.save.weight;
    return copyWith(
      score: lowered < 0 ? 0 : lowered,
      scoredCafes: {...scoredCafes}..remove(cafeId),
    );
  }

  /// A session starts at [now]: a return within the window adds its points
  /// once.
  EngagementState session(DateTime now) {
    final last = lastSessionAt;
    final isReturn =
        last != null &&
        !returnCounted &&
        now.difference(last) >= SignUpAskRules.sessionGap &&
        now.difference(last) <= SignUpAskRules.returnWindow;
    return copyWith(
      score: isReturn ? score + EngagementAction.returnSession.weight : score,
      lastSessionAt: now,
      returnCounted: returnCounted || isReturn,
    );
  }

  EngagementState asked(DateTime now, {int savesCount = 0}) =>
      copyWith(asks: asks + 1, lastAskAt: now, savesAtLastAsk: savesCount);

  /// The ask ended without a sign-in. [stay]: with "Keep using on this
  /// phone", which ends score asks.
  EngagementState dismissed({bool stay = false}) {
    final lowered = score - SignUpAskRules.dismissPenalty;
    return copyWith(
      score: lowered < 0 ? 0 : lowered,
      declines: declines + 1,
      stayOnPhone: stayOnPhone || stay,
    );
  }

  EngagementState copyWith({
    double? score,
    int? asks,
    DateTime? lastAskAt,
    DateTime? lastSessionAt,
    bool? returnCounted,
    int? declines,
    int? savesAtLastAsk,
    bool? stayOnPhone,
    Set<String>? scoredCafes,
  }) => EngagementState(
    score: score ?? this.score,
    asks: asks ?? this.asks,
    lastAskAt: lastAskAt ?? this.lastAskAt,
    lastSessionAt: lastSessionAt ?? this.lastSessionAt,
    returnCounted: returnCounted ?? this.returnCounted,
    declines: declines ?? this.declines,
    savesAtLastAsk: savesAtLastAsk ?? this.savesAtLastAsk,
    stayOnPhone: stayOnPhone ?? this.stayOnPhone,
    scoredCafes: scoredCafes ?? this.scoredCafes,
  );

  Map<String, Object?> toJson() => {
    'score': score,
    'asks': asks,
    'last_ask_at': lastAskAt?.toUtc().toIso8601String(),
    'last_session_at': lastSessionAt?.toUtc().toIso8601String(),
    'return_counted': returnCounted,
    'declines': declines,
    'saves_at_last_ask': savesAtLastAsk,
    'stay_on_phone': stayOnPhone,
    'scored_cafes': scoredCafes.toList(),
  };

  static EngagementState fromJson(Object? json) {
    if (json is! Map) return const EngagementState();
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
    int count(Object? v) => v is int ? v : 0;
    final score = json['score'];
    final cafes = json['scored_cafes'];
    return EngagementState(
      score: score is num ? score.toDouble() : 0,
      asks: count(json['asks']),
      lastAskAt: date(json['last_ask_at']),
      lastSessionAt: date(json['last_session_at']),
      returnCounted: json['return_counted'] == true,
      declines: count(json['declines']),
      savesAtLastAsk: count(json['saves_at_last_ask']),
      stayOnPhone: json['stay_on_phone'] == true,
      scoredCafes: cafes is List ? {...cafes.whereType<String>()} : const {},
    );
  }

  @override
  List<Object?> get props => [
    score,
    asks,
    lastAskAt,
    lastSessionAt,
    returnCounted,
    declines,
    savesAtLastAsk,
    stayOnPhone,
    scoredCafes,
  ];
}
