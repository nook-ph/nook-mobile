import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/repositories/i_cafe_repository.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/core/extensions/extensions.dart';

/// How the ranking sheet ended, so the caller knows which toast (if any) to
/// show. A null result from the sheet means it was dismissed — treated as
/// [skipped], because the Been mark is already saved either way.
enum RankingFlowOutcome {
  /// User chose "Skip for now" or dismissed the sheet — no ranking written.
  skipped,

  /// Ranked and revealed; the score screen was the feedback, no toast needed.
  completed,

  /// Ranked, and the user asked to add a note — the caller opens the note
  /// sheet with its own (still-mounted) context; opening it from inside this
  /// sheet would use a context that was popped a frame earlier.
  completedAddNote,

  /// The write failed. The Been mark is safe; only the score was lost.
  failed,
}

/// The post-Been flow (spec: docs/RANKING_DESIGN.md §3.1): bucket → up to four
/// head-to-head comparisons → score reveal. Every step is skippable and the
/// Been mark is already persisted before this opens — ranking is the dessert,
/// not the bill.
Future<RankingFlowOutcome?> showCafeRankingFlow(
  BuildContext context, {
  required CafeRankingCubit cubit,
  required String cafeId,
  required String cafeName,
  String? cafeImageUrl,
}) {
  return showModalBottomSheet<RankingFlowOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CafeRankingFlow(
      cubit: cubit,
      cafeId: cafeId,
      cafeName: cafeName,
      cafeImageUrl: cafeImageUrl,
    ),
  );
}

enum _Phase { bucket, compare, saving, reveal }

class _CafeRankingFlow extends StatefulWidget {
  const _CafeRankingFlow({
    required this.cubit,
    required this.cafeId,
    required this.cafeName,
    this.cafeImageUrl,
  });

  final CafeRankingCubit cubit;
  final String cafeId;
  final String cafeName;
  final String? cafeImageUrl;

  @override
  State<_CafeRankingFlow> createState() => _CafeRankingFlowState();
}

class _CafeRankingFlowState extends State<_CafeRankingFlow> {
  static const _green = Color(0xFF3A5A40);

  _Phase _phase = _Phase.bucket;
  RankingFlowOutcome? _outcome;
  CafeRanking? _result;
  int? _overallRank;
  int _rankedCount = 0;

  @override
  void dispose() {
    // Swipe-down / barrier dismissal skips _finish, so an open session would
    // otherwise linger on the app-wide cubit and leak into the next flow.
    if (_outcome == null) widget.cubit.cancelSession();
    super.dispose();
  }

  void _finish(RankingFlowOutcome outcome) {
    _outcome = outcome;
    Navigator.pop(context, outcome);
  }

  void _track(String event, [Map<String, dynamic>? extra]) {
    unawaited(
      sl<AnalyticsService>().track(
        widget.cafeId,
        event,
        metadata: {AnalyticsMetadataKeys.screen: 'cafe_details', ...?extra},
      ),
    );
  }

  void _onBucketChosen(RankBucket bucket) {
    _track('rank_bucket_chosen', {'bucket': bucket.wire});
    final session = widget.cubit.startSession(widget.cafeId, bucket);
    if (session.isComplete) {
      // Nothing to compare against — first cafe in this bucket.
      _commit();
    } else {
      setState(() => _phase = _Phase.compare);
    }
  }

  void _onComparisonPicked({required bool preferredTarget}) {
    final session = widget.cubit.state.session;
    if (session == null) return;
    _track('rank_comparison_answered', {
      'comparison_index': session.comparisonsAsked + 1,
      'preferred_new': preferredTarget,
    });
    widget.cubit.answerComparison(preferredTarget: preferredTarget);
    if (widget.cubit.state.session?.isComplete ?? true) {
      _commit();
    } else {
      setState(() {});
    }
  }

  void _onTooClose() {
    _track('rank_skipped', {
      'comparisons_answered': widget.cubit.state.session?.comparisonsAsked ?? 0,
    });
    widget.cubit.skipComparisons();
    _commit();
  }

  Future<void> _commit() async {
    setState(() => _phase = _Phase.saving);
    final ranking = await widget.cubit.commitSession();
    if (!mounted) return;

    if (ranking == null) {
      _finish(RankingFlowOutcome.failed);
      return;
    }

    _track('rank_completed', {
      'bucket': ranking.bucket.wire,
      'score': ranking.score,
      'position': ranking.position,
    });
    // The score reveal is this feature's "stamp" moment.
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _result = ranking;
      _overallRank = widget.cubit.state.overallRankOf(widget.cafeId);
      _rankedCount = widget.cubit.state.rankedCount;
      _phase = _Phase.reveal;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (_phase) {
                _Phase.bucket => _BucketStep(
                  key: const ValueKey('bucket'),
                  cafeName: widget.cafeName,
                  onChosen: _onBucketChosen,
                  onSkip: () => _finish(RankingFlowOutcome.skipped),
                ),
                _Phase.compare => _CompareStep(
                  key: ValueKey(
                    'compare-${widget.cubit.state.session?.comparisonsAsked}',
                  ),
                  cafeName: widget.cafeName,
                  cafeImageUrl: widget.cafeImageUrl,
                  opponentId: widget.cubit.state.session?.currentOpponent,
                  onPicked: _onComparisonPicked,
                  onTooClose: _onTooClose,
                ),
                _Phase.saving => const Padding(
                  key: ValueKey('saving'),
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: CircularProgressIndicator(color: _green),
                ),
                _Phase.reveal => _RevealStep(
                  key: const ValueKey('reveal'),
                  cafeId: widget.cafeId,
                  cafeName: widget.cafeName,
                  ranking: _result!,
                  overallRank: _overallRank,
                  rankedCount: _rankedCount,
                  onDone: () => _finish(RankingFlowOutcome.completed),
                  onAddNote: () => _finish(RankingFlowOutcome.completedAddNote),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 1: bucket ─────────────────────────────────────────────────────────

class _BucketStep extends StatelessWidget {
  const _BucketStep({
    super.key,
    required this.cafeName,
    required this.onChosen,
    required this.onSkip,
  });

  final String cafeName;
  final ValueChanged<RankBucket> onChosen;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How was $cafeName?',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.titleMediumSemi,
        ),
        const SizedBox(height: 20),
        _BucketOption(
          emoji: '😍',
          label: 'Liked it',
          onTap: () => onChosen(RankBucket.liked),
        ),
        const SizedBox(height: 10),
        _BucketOption(
          emoji: '🙂',
          label: 'It was fine',
          onTap: () => onChosen(RankBucket.fine),
        ),
        const SizedBox(height: 10),
        _BucketOption(
          emoji: '😕',
          label: 'Not for me',
          onTap: () => onChosen(RankBucket.disliked),
        ),
        const SizedBox(height: 14),
        AdaptiveTap(
          onTap: onSkip,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Skip for now',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMediumMed.copyWith(
                color: const Color(0xFF868584),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BucketOption extends StatelessWidget {
  const _BucketOption({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(label, style: context.textTheme.bodyLargeMed),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: head-to-head ───────────────────────────────────────────────────

class _CompareStep extends StatelessWidget {
  const _CompareStep({
    super.key,
    required this.cafeName,
    required this.cafeImageUrl,
    required this.opponentId,
    required this.onPicked,
    required this.onTooClose,
  });

  final String cafeName;
  final String? cafeImageUrl;
  final String? opponentId;
  final void Function({required bool preferredTarget}) onPicked;
  final VoidCallback onTooClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Which did you like more?',
          textAlign: TextAlign.center,
          style: context.textTheme.titleMediumSemi,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _CompareCard(
                name: cafeName,
                imageUrl: cafeImageUrl,
                onTap: () => onPicked(preferredTarget: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: opponentId == null
                  ? const SizedBox.shrink()
                  : _OpponentCard(
                      cafeId: opponentId!,
                      onTap: () => onPicked(preferredTarget: false),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AdaptiveTap(
          onTap: onTooClose,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
            child: Text(
              'Too close — skip',
              style: context.textTheme.bodyMediumMed.copyWith(
                color: const Color(0xFF868584),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Resolves an opponent id to a name + photo through the repository, which is
/// backed by the CafeStore cache — after the first comparison most opponents
/// are already local. Failure shows a name-less card that is still tappable:
/// blocking the flow on a thumbnail would be backwards.
class _OpponentCard extends StatelessWidget {
  const _OpponentCard({required this.cafeId, required this.onTap});

  final String cafeId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: sl<ICafeRepository>().getCafeBundleById(
        cafeId,
        includeMenu: false,
        includeReviews: false,
      ),
      builder: (context, snapshot) {
        final details = snapshot.data?.details;
        return _CompareCard(
          name: details?.name ?? 'This cafe',
          imageUrl: details?.coverImage,
          onTap: onTap,
        );
      },
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({
    required this.name,
    required this.imageUrl,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (url != null && url.isNotEmpty)
              CafeCardImage(imageUrl: url, height: 110, width: double.infinity)
            else
              Container(
                height: 110,
                color: const Color(0xFFEEEEEE),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.coffee_outlined,
                  color: Color(0xFF868584),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMediumMed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: the payoff ─────────────────────────────────────────────────────

class _RevealStep extends StatelessWidget {
  const _RevealStep({
    super.key,
    required this.cafeId,
    required this.cafeName,
    required this.ranking,
    required this.overallRank,
    required this.rankedCount,
    required this.onDone,
    required this.onAddNote,
  });

  final String cafeId;
  final String cafeName;
  final CafeRanking ranking;
  final int? overallRank;
  final int rankedCount;
  final VoidCallback onDone;
  final VoidCallback onAddNote;

  static const _green = Color(0xFF3A5A40);

  @override
  Widget build(BuildContext context) {
    final rankLine = rankedCount <= 1
        ? 'Your first ranked cafe ☕'
        : '#${overallRank ?? ranking.position} of $rankedCount · My Cebu Cafes';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          cafeName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.titleMediumSemi,
        ),
        const SizedBox(height: 8),
        Text(
          ranking.displayScore,
          textAlign: TextAlign.center,
          style: context.textTheme.titleMediumSemi.copyWith(
            fontSize: 56,
            height: 1.1,
            color: _green,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          rankLine,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMediumMed.copyWith(
            color: const Color(0xFF868584),
          ),
        ),
        const SizedBox(height: 22),
        AdaptiveTap(
          onTap: onDone,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Done',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyLargeMed.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AdaptiveTap(
          onTap: onAddNote,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Add a note',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMediumMed.copyWith(color: _green),
            ),
          ),
        ),
      ],
    );
  }
}
