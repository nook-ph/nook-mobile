import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_ranking.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/presentation/widgets/cafe_score_chip.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_note_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_ranking_flow.dart';

/// The Been list rendered as the personal ranking (spec:
/// docs/RANKING_DESIGN.md §3.2): ranked cafes in order with score chips and
/// note snippets, then a "Not ranked yet" section whose Rank buttons launch
/// the same flow that follows a fresh Been — which makes it the backfill path
/// for cafes logged before ranking existed.
class RankedBeenList extends StatelessWidget {
  const RankedBeenList({super.key, required this.cafes});

  /// All cafes on the Been list (any order — this widget re-orders).
  final List<CafeSummary> cafes;

  static const _green = Color(0xFF3A5A40);

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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < ranked.length; i++) ...[
              _RankedRow(
                rank: i + 1,
                cafe: ranked[i].cafe,
                ranking: ranked[i].ranking,
              ),
              const SizedBox(height: 12),
            ],
            if (ranked.isNotEmpty && unranked.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Not ranked yet',
                style: context.textTheme.titleMediumSemi.copyWith(
                  color: const Color(0xFF1E3A2B),
                ),
              ),
              const SizedBox(height: 12),
            ],
            for (final cafe in unranked) ...[
              _UnrankedRow(cafe: cafe),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

/// Shared row chrome: thumbnail, name + secondary line, trailing control.
class _BeenRow extends StatelessWidget {
  const _BeenRow({
    required this.cafe,
    required this.trailing,
    this.leading,
    this.secondary,
  });

  final CafeSummary cafe;
  final Widget trailing;
  final Widget? leading;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CafeDetailsPage(cafeId: cafe.id)),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: (cafe.coverImage?.trim().isNotEmpty ?? false)
                  ? CafeCardImage(
                      imageUrl: cafe.coverImage!.trim(),
                      height: 48,
                      width: 48,
                    )
                  : Container(
                      height: 48,
                      width: 48,
                      color: const Color(0xFFEEEEEE),
                      child: const Icon(
                        Icons.coffee_outlined,
                        size: 20,
                        color: Color(0xFF868584),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cafe.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyLargeMed,
                  ),
                  if (secondary != null) ...[
                    const SizedBox(height: 2),
                    secondary!,
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing,
          ],
        ),
      ),
    );
  }
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
    final note = cafe.note?.trim();

    return _BeenRow(
      cafe: cafe,
      leading: SizedBox(
        width: 22,
        child: Text(
          '$rank',
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMediumMed.copyWith(
            color: const Color(0xFF868584),
          ),
        ),
      ),
      // The note is the journal finally getting a page: shown inline, tap
      // opens the existing sheet to read the rest or edit.
      secondary: note == null || note.isEmpty
          ? null
          : AdaptiveTap(
              onTap: () => showCafeNoteSheet(
                context,
                cafeId: cafe.id,
                cafeName: cafe.name,
              ),
              child: Text(
                '“$note”',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmallMed.copyWith(
                  color: const Color(0xFF868584),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
      // Tapping your score re-opens the flow — that IS the re-rank tool
      // (drag-to-reorder stays in the v2 parking lot).
      trailing: CafeScoreChip(
        score: ranking.displayScore,
        onTap: () => _rerank(context),
      ),
    );
  }

  void _rerank(BuildContext context) {
    showCafeRankingFlow(
      context,
      cubit: context.read<CafeRankingCubit>(),
      cafeId: cafe.id,
      cafeName: cafe.name,
      cafeImageUrl: cafe.coverImage,
    );
  }
}

class _UnrankedRow extends StatelessWidget {
  const _UnrankedRow({required this.cafe});

  final CafeSummary cafe;

  @override
  Widget build(BuildContext context) {
    return _BeenRow(
      cafe: cafe,
      trailing: AdaptiveTap(
        onTap: () {
          showCafeRankingFlow(
            context,
            cubit: context.read<CafeRankingCubit>(),
            cafeId: cafe.id,
            cafeName: cafe.name,
            cafeImageUrl: cafe.coverImage,
          );
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: RankedBeenList._green,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Rank',
            style: context.textTheme.bodySmallMed.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
