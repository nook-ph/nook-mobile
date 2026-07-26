import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_ranking_flow.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// The Been list as the personal ranking (spec: docs/RANKING_DESIGN.md §3.2),
/// rebuilt from the Claude Design project "Lists & Been Ranking".
///
/// Three states, all handled here: cafes ranked (summary + banded rows),
/// cafes logged but none ranked yet (an invitation, not a bare list of
/// buttons), and the transition between them.
class RankedBeenList extends StatelessWidget {
  const RankedBeenList({super.key, required this.cafes});

  /// All cafes on the Been list (any order — this widget re-orders).
  final List<CafeSummary> cafes;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CafeRankingCubit, CafeRankingState>(
      builder: (context, state) {
        final byId = {for (final cafe in cafes) cafe.id: cafe};

        // Ranked cafes in the cubit's order (liked → fine → disliked, best
        // first). A ranking whose cafe isn't on the list (mid-refresh) is
        // skipped rather than rendered as a ghost row.
        final ranked = [
          for (final r in state.rankings)
            if (byId.containsKey(r.cafeId)) (cafe: byId[r.cafeId]!, ranking: r),
        ];
        final rankedIds = {for (final e in ranked) e.cafe.id};
        final unranked = [
          for (final cafe in cafes)
            if (!rankedIds.contains(cafe.id)) cafe,
        ];

        if (ranked.isEmpty) {
          return _ZeroRankedView(cafes: unranked);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopRankSummary(
              top: ranked.first,
              rankedCount: ranked.length,
              toRankCount: unranked.length,
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < ranked.length; i++) ...[
              // The bands are the structure the user actually built — they
              // were asked "how was it?" and the list is sorted by the answer.
              // Without them nine rows read as one undifferentiated run.
              if (i == 0 ||
                  ranked[i].ranking.bucket != ranked[i - 1].ranking.bucket)
                _SectionHeader(
                  label: _bandLabel(ranked[i].ranking.bucket),
                  count: _bandCount(ranked, ranked[i].ranking.bucket),
                  color: ListsTokens.brand,
                  topGap: i == 0 ? 6 : 14,
                ),
              _RankedRow(
                rank: i + 1,
                total: ranked.length,
                cafe: ranked[i].cafe,
                ranking: ranked[i].ranking,
              ),
              if (i != ranked.length - 1) const SizedBox(height: 8),
            ],
            if (unranked.isNotEmpty) ...[
              _SectionHeader(
                label: 'Not ranked yet',
                count: unranked.length,
                color: ListsTokens.muted,
                topGap: 14,
              ),
              for (var i = 0; i < unranked.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _UnrankedRow(cafe: unranked[i], indent: true),
              ],
            ],
          ],
        );
      },
    );
  }

  static String _bandLabel(RankBucket bucket) => switch (bucket) {
    RankBucket.liked => 'Liked it',
    RankBucket.fine => 'It was fine',
    RankBucket.disliked => 'Not for me',
  };

  static int _bandCount(
    List<({CafeSummary cafe, CafeRanking ranking})> ranked,
    RankBucket bucket,
  ) {
    var count = 0;
    for (final entry in ranked) {
      if (entry.ranking.bucket == bucket) count++;
    }
    return count;
  }
}

// ── The payoff ─────────────────────────────────────────────────────────────

/// Opens the page on the user's #1 with the one large number the type scale
/// allows. The comparisons earned a result; the list used to show nine
/// identical rows and no sense that anything had been achieved.
class _TopRankSummary extends StatelessWidget {
  const _TopRankSummary({
    required this.top,
    required this.rankedCount,
    required this.toRankCount,
  });

  final ({CafeSummary cafe, CafeRanking ranking}) top;
  final int rankedCount;
  final int toRankCount;

  @override
  Widget build(BuildContext context) {
    final subtitle = toRankCount == 0
        ? '$rankedCount ranked'
        : '$rankedCount ranked · $toRankCount to rank';

    return AdaptiveTap(
      onTap: () => _openCafe(context, top.cafe),
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: ListsTokens.surface,
          borderRadius: BorderRadius.circular(ListsTokens.radius),
          border: Border.all(color: ListsTokens.border),
        ),
        child: Row(
          children: [
            _CafeThumb(cafe: top.cafe),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your #1 · ${top.cafe.name}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyLargeMed.copyWith(
                      color: ListsTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: ListsTokens.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              top.ranking.displayScore,
              style: context.textTheme.titleLargeSemi.copyWith(
                fontSize: 32,
                height: 1.1,
                color: ListsTokens.score,
                letterSpacing: ListsTokens.tracking(32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rows ───────────────────────────────────────────────────────────────────

/// Row chrome shared by ranked and unranked entries: one bordered container
/// split by a hairline into two sibling tap targets — open the cafe, or rank
/// it. Nothing is nested inside anything else.
class _BeenRow extends StatelessWidget {
  const _BeenRow({
    required this.cafe,
    required this.trailing,
    required this.onTrailingTap,
    this.leading,
    this.secondary,
    this.indent = false,
  });

  final CafeSummary cafe;
  final Widget trailing;
  final VoidCallback onTrailingTap;
  final Widget? leading;
  final Widget? secondary;

  /// Aligns a thumbnail with the ranked rows' thumbnails, which sit after the
  /// rank number.
  final bool indent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ListsTokens.surface,
        borderRadius: BorderRadius.circular(ListsTokens.radius),
        border: Border.all(color: ListsTokens.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AdaptiveTap(
                onTap: () => _openCafe(context, cafe),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 12),
                      ],
                      if (indent) const SizedBox(width: 36),
                      _CafeThumb(cafe: cafe),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cafe.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodyLargeMed.copyWith(
                                color: ListsTokens.ink,
                              ),
                            ),
                            if (secondary != null) ...[
                              const SizedBox(height: 2),
                              secondary!,
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(width: 1, color: ListsTokens.border),
            AdaptiveTap(
              onTap: onTrailingTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 104),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Center(child: trailing),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({
    required this.rank,
    required this.total,
    required this.cafe,
    required this.ranking,
  });

  final int rank;
  final int total;
  final CafeSummary cafe;
  final CafeRanking ranking;

  @override
  Widget build(BuildContext context) {
    final note = cafe.note?.trim();

    return _BeenRow(
      cafe: cafe,
      leading: SizedBox(
        width: 24,
        child: Text(
          '$rank',
          textAlign: TextAlign.center,
          style: context.textTheme.titleMediumSemi.copyWith(
            color: ListsTokens.brand,
          ),
        ),
      ),
      // The note reads as a quote belonging to the cafe. It is deliberately
      // not tappable: it used to open the note sheet from inside a row whose
      // own tap opened the cafe, which was a sub-48pt target and a coin flip.
      // Editing lives on the cafe page.
      secondary: note == null || note.isEmpty
          ? null
          : Text(
              '“$note”',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodySmall?.copyWith(
                color: ListsTokens.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
      onTrailingTap: () => _openRankingFlow(context, cafe),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // "8.4 · #3 of 9" is one reading. A bare score reads as a review of
          // the cafe; the pair reads as a position in your own list
          // (docs/RANKING_DESIGN.md §3.3).
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: ranking.displayScore,
                  style: context.textTheme.bodyLargeMed.copyWith(
                    color: ListsTokens.score,
                  ),
                ),
                TextSpan(
                  text: ' · #$rank of $total',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: ListsTokens.muted,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.end,
          ),
          const SizedBox(height: 3),
          // Tapping the score used to be the only way to re-rank, with nothing
          // to say so. Drag-to-reorder is deliberately not built — the
          // comparison flow is the re-rank tool, so it gets a label.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIcons.arrowsDownUp(),
                size: 12,
                color: ListsTokens.score,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Re-rank',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmallMed.copyWith(
                    color: ListsTokens.score,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnrankedRow extends StatelessWidget {
  const _UnrankedRow({required this.cafe, this.indent = false});

  final CafeSummary cafe;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    return _BeenRow(
      cafe: cafe,
      indent: indent,
      onTrailingTap: () => _openRankingFlow(context, cafe),
      // Outlined rather than filled: it sits in the same slot as "Re-rank"
      // above it, and a wall of solid green buttons made the unranked tail
      // shout louder than the ranking itself.
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: ListsTokens.accent),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Rank',
          style: context.textTheme.bodySmallMed.copyWith(
            color: ListsTokens.brand,
          ),
        ),
      ),
    );
  }
}

// ── Zero ranked ────────────────────────────────────────────────────────────

/// Every new user, and every account backfilling Beens logged before ranking
/// existed. The old build suppressed even the "Not ranked yet" heading here,
/// so this state was an unexplained list of rows with green buttons.
class _ZeroRankedView extends StatelessWidget {
  const _ZeroRankedView({required this.cafes});

  final List<CafeSummary> cafes;

  @override
  Widget build(BuildContext context) {
    final count = cafes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ListsTokens.radius),
            border: Border.all(color: ListsTokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Turn $count ${count == 1 ? 'visit' : 'visits'} into your '
                'ranking',
                style: context.textTheme.titleMediumSemi.copyWith(
                  color: ListsTokens.ink,
                  letterSpacing: ListsTokens.tracking(18),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Pick how each one felt, answer a couple of “which did you '
                'like more?” questions, and your list orders itself. About 20 '
                'seconds per cafe.',
                style: context.textTheme.bodyLarge?.copyWith(
                  color: ListsTokens.muted,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 14),
              _FilledPill(
                label: 'Rank your first cafe',
                onTap: cafes.isEmpty
                    ? null
                    : () => _openRankingFlow(context, cafes.first),
              ),
            ],
          ),
        ),
        const _SectionHeader(
          label: 'Your Beens',
          count: null,
          color: ListsTokens.muted,
          topGap: 24,
        ),
        for (var i = 0; i < cafes.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _UnrankedRow(cafe: cafes[i]),
        ],
      ],
    );
  }
}

/// No Beens at all — the diary hasn't started. Rendered by `ListDetailPage`
/// in place of its generic "No cafes in this list yet."
class BeenEmptyState extends StatelessWidget {
  const BeenEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 64),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: ListsTokens.sage,
              borderRadius: BorderRadius.circular(ListsTokens.radius),
            ),
            alignment: Alignment.center,
            child: Icon(
              PhosphorIcons.coffee(),
              size: 28,
              color: ListsTokens.brand,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Nowhere yet',
            textAlign: TextAlign.center,
            style: context.textTheme.titleMediumSemi.copyWith(
              color: ListsTokens.ink,
              letterSpacing: ListsTokens.tracking(18),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Mark a cafe as Been and your diary starts here — ranked by you, '
            'not by reviews.',
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge?.copyWith(
              color: ListsTokens.muted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 20),
          AdaptiveTap(
            onTap: () => context.push('/search'),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: ListsTokens.accent),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                'Find a cafe',
                style: context.textTheme.bodyLargeMed.copyWith(
                  color: ListsTokens.brand,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared bits ────────────────────────────────────────────────────────────

/// A quiet caption with a rule running to the edge — enough to break the list
/// into bands without competing with the rows.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.count,
    required this.color,
    required this.topGap,
  });

  final String label;
  final int? count;
  final Color color;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topGap, bottom: 10),
      child: Row(
        children: [
          Text(
            count == null ? label : '$label · $count',
            style: context.textTheme.bodySmallMed.copyWith(color: color),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1, color: ListsTokens.border)),
        ],
      ),
    );
  }
}

class _CafeThumb extends StatelessWidget {
  const _CafeThumb({required this.cafe});

  final CafeSummary cafe;

  @override
  Widget build(BuildContext context) {
    final url = cafe.coverImage?.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      child: url != null && url.isNotEmpty
          ? CafeCardImage(imageUrl: url, height: 48, width: 48)
          : Container(
              height: 48,
              width: 48,
              color: ListsTokens.sage,
              alignment: Alignment.center,
              child: Icon(
                PhosphorIcons.coffee(),
                size: 20,
                color: ListsTokens.brand,
              ),
            ),
    );
  }
}

class _FilledPill extends StatelessWidget {
  const _FilledPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: onTap == null ? ListsTokens.brandHover : ListsTokens.brand,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: context.textTheme.bodyLargeMed.copyWith(
            color: ListsTokens.surface,
          ),
        ),
      ),
    );
  }
}

void _openCafe(BuildContext context, CafeSummary cafe) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => CafeDetailsPage(cafeId: cafe.id)),
  );
}

void _openRankingFlow(BuildContext context, CafeSummary cafe) {
  showCafeRankingFlow(
    context,
    cubit: context.read<CafeRankingCubit>(),
    cafeId: cafe.id,
    cafeName: cafe.name,
    cafeImageUrl: cafe.coverImage,
  );
}
