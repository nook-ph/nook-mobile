import 'package:equatable/equatable.dart';

/// Which band a ranked cafe sits in. Chosen with one tap before any
/// comparison, so the band is fixed and comparisons only order cafes
/// *within* it — that is what keeps the flow short (spec §1).
enum RankBucket {
  liked('liked'),
  fine('fine'),
  disliked('disliked');

  const RankBucket(this.wire);

  /// Value used by the `set_cafe_ranking` RPC.
  final String wire;

  static RankBucket? fromWire(String? value) {
    return switch (value) {
      'liked' => RankBucket.liked,
      'fine' => RankBucket.fine,
      'disliked' => RankBucket.disliked,
      _ => null,
    };
  }

  /// Display order: liked cafes rank above fine, which rank above disliked.
  int get sortOrder => switch (this) {
    RankBucket.liked => 0,
    RankBucket.fine => 1,
    RankBucket.disliked => 2,
  };
}

/// One cafe's place in the caller's personal ranking.
///
/// [position] is 1-based and dense *within* a bucket; [score] is derived
/// server-side from the bucket's band and the position. Both are owned by the
/// database — the client never computes them, it only proposes a position.
class CafeRanking extends Equatable {
  const CafeRanking({
    required this.cafeId,
    required this.bucket,
    required this.position,
    required this.score,
  });

  final String cafeId;
  final RankBucket bucket;
  final int position;
  final double score;

  /// "8.4" — one decimal, matching the numeric(3,1) the server stores.
  String get displayScore => score.toStringAsFixed(1);

  @override
  List<Object?> get props => [cafeId, bucket, position, score];
}
