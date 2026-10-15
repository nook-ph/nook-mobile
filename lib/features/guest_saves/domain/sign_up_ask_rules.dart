import 'package:equatable/equatable.dart';

/// What a guest did that counts toward asking them to sign in. Weights are
/// Pinterest web's starting values (teardowns brief, section 1).
enum EngagementAction {
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

/// When the soft "keep your saves" ask may show. The ask can always be
/// dismissed; saves stay unlimited either way.
abstract final class SignUpAskRules {
  /// Asked at or above this score.
  static const threshold = 20.0;

  /// Each dismissal takes this off the score.
  static const dismissPenalty = 5.0;

  /// At most one ask in this long.
  static const cooldown = Duration(days: 7);

  /// Never more than this many asks on one phone.
  static const maxAsks = 3;

  /// A session after this long away counts as a return...
  static const sessionGap = Duration(minutes: 30);

  /// ...when it comes within this long of the last session.
  static const returnWindow = Duration(days: 30);

  /// Whether to ask now. [hasSaves]: the ask is about keeping saves, so a
  /// guest with nothing saved is never asked.
  static bool shouldAsk(
    EngagementState state, {
    required DateTime now,
    required bool hasSaves,
    double threshold = SignUpAskRules.threshold,
  }) {
    if (!hasSaves) return false;
    if (state.score < threshold) return false;
    if (state.asks >= maxAsks) return false;
    final last = state.lastAskAt;
    if (last != null && now.difference(last) < cooldown) return false;
    return true;
  }
}

/// The guest's engagement, kept on the phone.
class EngagementState extends Equatable {
  const EngagementState({
    this.score = 0,
    this.asks = 0,
    this.lastAskAt,
    this.lastSessionAt,
    this.returnCounted = false,
  });

  final double score;

  /// How many times the ask has been shown.
  final int asks;
  final DateTime? lastAskAt;

  /// When the last session started.
  final DateTime? lastSessionAt;

  /// The return-session points have been given.
  final bool returnCounted;

  EngagementState add(EngagementAction action) =>
      copyWith(score: score + action.weight);

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

  EngagementState asked(DateTime now) =>
      copyWith(asks: asks + 1, lastAskAt: now);

  EngagementState dismissed() {
    final lowered = score - SignUpAskRules.dismissPenalty;
    return copyWith(score: lowered < 0 ? 0 : lowered);
  }

  EngagementState copyWith({
    double? score,
    int? asks,
    DateTime? lastAskAt,
    DateTime? lastSessionAt,
    bool? returnCounted,
  }) => EngagementState(
    score: score ?? this.score,
    asks: asks ?? this.asks,
    lastAskAt: lastAskAt ?? this.lastAskAt,
    lastSessionAt: lastSessionAt ?? this.lastSessionAt,
    returnCounted: returnCounted ?? this.returnCounted,
  );

  Map<String, Object?> toJson() => {
    'score': score,
    'asks': asks,
    'last_ask_at': lastAskAt?.toUtc().toIso8601String(),
    'last_session_at': lastSessionAt?.toUtc().toIso8601String(),
    'return_counted': returnCounted,
  };

  static EngagementState fromJson(Object? json) {
    if (json is! Map) return const EngagementState();
    DateTime? date(Object? v) => v is String ? DateTime.tryParse(v) : null;
    final score = json['score'];
    final asks = json['asks'];
    return EngagementState(
      score: score is num ? score.toDouble() : 0,
      asks: asks is int ? asks : 0,
      lastAskAt: date(json['last_ask_at']),
      lastSessionAt: date(json['last_session_at']),
      returnCounted: json['return_counted'] == true,
    );
  }

  @override
  List<Object?> get props => [
    score,
    asks,
    lastAskAt,
    lastSessionAt,
    returnCounted,
  ];
}
