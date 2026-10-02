import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_note_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_ranking_flow.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';

/// A Been cafe paired with its place in the ranking.
typedef RankedCafe = ({CafeSummary cafe, CafeRanking ranking});

/// Splits the Been list into its ranked cafes, in the cubit's order (liked →
/// fine → disliked, best first), and the ones still to rank. A ranking whose
/// cafe isn't on the list (mid-refresh) is skipped rather than rendered as a
/// ghost row.
({List<RankedCafe> ranked, List<CafeSummary> unranked}) splitBeenList(
  List<CafeSummary> cafes,
  List<CafeRanking> rankings,
) {
  final byId = {for (final cafe in cafes) cafe.id: cafe};
  final ranked = <RankedCafe>[
    for (final r in rankings)
      if (byId.containsKey(r.cafeId)) (cafe: byId[r.cafeId]!, ranking: r),
  ];
  final rankedIds = {for (final e in ranked) e.cafe.id};
  final unranked = [
    for (final cafe in cafes)
      if (!rankedIds.contains(cafe.id)) cafe,
  ];
  return (ranked: ranked, unranked: unranked);
}

/// The Been list as the personal ranking (spec: docs/RANKING_DESIGN.md §3.2;
/// Figma "Been — ranked"). It reads as a diary: rank, photo, name, your
/// note, score.
///
/// Three states, all handled here: cafes ranked (your #1, then banded rows),
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
        final split = splitBeenList(cafes, state.rankings);
        final ranked = split.ranked;
        final unranked = split.unranked;

        if (ranked.isEmpty) {
          return _ZeroRankedView(cafes: unranked);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopRankCard(top: ranked.first),
            for (var i = 0; i < ranked.length; i++) ...[
              // The bands are the structure the user actually built — they
              // were asked "how was it?" and the list is sorted by the answer.
              // Without them nine rows read as one undifferentiated run.
              if (i == 0 ||
                  ranked[i].ranking.bucket != ranked[i - 1].ranking.bucket)
                _Band(
                  label:
                      '${_bandLabel(ranked[i].ranking.bucket)} · '
                      '${_bandCount(ranked, ranked[i].ranking.bucket)}',
                  color: ListsTokens.brand,
                ),
              _RankedRow(
                rank: i + 1,
                cafe: ranked[i].cafe,
                ranking: ranked[i].ranking,
              ),
            ],
            if (unranked.isNotEmpty) ...[
              _Band(
                label: 'Not ranked yet · ${unranked.length}',
                color: ListsTokens.muted,
              ),
              for (final cafe in unranked)
                _UnrankedRow(cafe: cafe, indent: true),
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

  static int _bandCount(List<RankedCafe> ranked, RankBucket bucket) {
    var count = 0;
    for (final entry in ranked) {
      if (entry.ranking.bucket == bucket) count++;
    }
    return count;
  }
}

// ── The payoff ─────────────────────────────────────────────────────────────

/// Opens the list on the user's #1 with the one large number on the page.
/// The comparisons earned a result; without this the list is a run of
/// identical rows and no sense that anything was achieved.
class _TopRankCard extends StatelessWidget {
  const _TopRankCard({required this.top});

  final RankedCafe top;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: () => _openCafe(context, top.cafe),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ListsTokens.tint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ListsThumb(imageUrl: top.cafe.coverImage, size: 48, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Your #1',
                    style: listsText(12, color: ListsTokens.muted),
                  ),
                  Text(
                    top.cafe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: listsText(16, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              top.ranking.displayScore,
              style: listsText(
                24,
                weight: FontWeight.w600,
                color: ListsTokens.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rows ───────────────────────────────────────────────────────────────────

/// The line under a cafe's name: the user's note as a quote when there is
/// one, otherwise where the cafe is.
Widget? _secondaryLine(CafeSummary cafe, {required bool preferNote}) {
  final note = cafe.note?.trim();
  final text = preferNote && note != null && note.isNotEmpty
      ? '“$note”'
      : cafe.locationLabel.trim();
  if (text.isEmpty) return null;
  return Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: listsText(12, color: ListsTokens.muted),
  );
}

class _RankedRow extends StatelessWidget {
  const _RankedRow({
    required this.rank,
    required this.cafe,
    required this.ranking,
  });

  final int rank;
  final CafeSummary cafe;
  final CafeRanking ranking;

  @override
  Widget build(BuildContext context) {
    // The note reads as a quote belonging to the cafe. It is deliberately
    // not tappable: editing lives on the cafe page.
    final secondary = _secondaryLine(cafe, preferNote: true);

    return Row(
      children: [
        Expanded(
          child: AdaptiveTap(
            onTap: () => _openCafe(context, cafe),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Wide enough for two digits; the photo column stays put.
                  SizedBox(
                    width: 16,
                    child: Text(
                      '$rank',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                      style: listsText(14, weight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ListsThumb(imageUrl: cafe.coverImage, size: 44, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cafe.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: listsText(14, weight: FontWeight.w500),
                        ),
                        ?secondary,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Drag-to-reorder is deliberately not built — the comparison flow is
        // the re-rank tool, so the score carries a small labelled link to it.
        Semantics(
          button: true,
          label: 'Score ${ranking.displayScore}. Re-rank ${cafe.name}',
          excludeSemantics: true,
          child: AdaptiveTap(
            onTap: () => _openRankingFlow(context, cafe),
            borderRadius: BorderRadius.circular(ListsTokens.radius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ranking.displayScore,
                    style: listsText(
                      16,
                      weight: FontWeight.w600,
                      color: ListsTokens.brand,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.arrowUpDown,
                        size: 10,
                        color: ListsTokens.muted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Re-rank',
                        style: listsText(10, color: ListsTokens.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UnrankedRow extends StatelessWidget {
  const _UnrankedRow({required this.cafe, this.indent = false});

  final CafeSummary cafe;

  /// Lines the photo up with the ranked rows' photos, which sit after the
  /// rank number.
  final bool indent;

  @override
  Widget build(BuildContext context) {
    final secondary = _secondaryLine(cafe, preferNote: false);

    return Row(
      children: [
        Expanded(
          child: AdaptiveTap(
            onTap: () => _openCafe(context, cafe),
            child: Padding(
              padding: EdgeInsets.only(
                left: indent ? 28 : 0,
                top: 8,
                bottom: 8,
              ),
              child: Row(
                children: [
                  ListsThumb(imageUrl: cafe.coverImage, size: 44, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cafe.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: listsText(14, weight: FontWeight.w500),
                        ),
                        ?secondary,
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ListsPillButton(
          label: 'Rank',
          style: ListsPillStyle.outlined,
          height: 32,
          fontSize: 12,
          horizontalPadding: 14,
          expand: false,
          onTap: () => _openRankingFlow(context, cafe),
        ),
      ],
    );
  }
}

// ── Zero ranked ────────────────────────────────────────────────────────────

/// Every new user, and every account backfilling Beens logged before ranking
/// existed (Figma "Been — nothing ranked").
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
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: ListsTokens.tint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Turn $count ${count == 1 ? 'visit' : 'visits'} into your '
                'ranking',
                style: listsText(16, weight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick how each one felt, answer a couple of “which did you '
                'like more?” questions, and your list orders itself. About 20 '
                'seconds per cafe.',
                style: listsText(14, color: ListsTokens.muted),
              ),
              // The design's 4 spacer between two 8 gaps.
              const SizedBox(height: 20),
              ListsPillButton(
                label: 'Rank your first cafe',
                height: 44,
                expand: false,
                onTap: cafes.isEmpty
                    ? null
                    : () => _openRankingFlow(context, cafes.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        _Band(label: 'Your Beens · $count', color: ListsTokens.muted),
        for (final cafe in cafes) _UnrankedRow(cafe: cafe),
      ],
    );
  }
}

// ── Shared bits ────────────────────────────────────────────────────────────

/// A quiet caption with a rule running to the edge — enough to break the list
/// into bands without competing with the rows.
class _Band extends StatelessWidget {
  const _Band({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The design's 10 / 2, plus the 2 the rows sit apart.
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: listsText(12, weight: FontWeight.w500, color: color),
          ),
          const SizedBox(width: 10),
          const Expanded(child: ListsDivider()),
        ],
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

/// Ranks [cafe], then honours the reveal's "Add a note": the sheet has been
/// popped by then, so the note sheet opens from this still-mounted context.
/// "View my list" needs nothing here — this is the list.
Future<void> _openRankingFlow(BuildContext context, CafeSummary cafe) async {
  final outcome = await showCafeRankingFlow(
    context,
    cubit: context.read<CafeRankingCubit>(),
    cafeId: cafe.id,
    cafeName: cafe.name,
    cafeImageUrl: cafe.coverImage,
    cafeLocation: cafe.locationLabel,
  );
  if (!context.mounted) return;

  switch (outcome) {
    case RankingFlowOutcome.completedAddNote:
      await showCafeNoteSheet(context, cafeId: cafe.id, cafeName: cafe.name);
    case RankingFlowOutcome.failed:
      showRankingFailedToast(context);
    case RankingFlowOutcome.completed ||
        RankingFlowOutcome.completedViewList ||
        RankingFlowOutcome.skipped ||
        null:
      break;
  }
}
