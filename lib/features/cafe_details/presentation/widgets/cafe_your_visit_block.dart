import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/cafe/domain/use_cases/get_cafe_note_usecase.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_note_sheet.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_ranking_flow.dart';
import 'package:nook/features/lists/presentation/utils/open_been_list.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// "Your visit" — the user's own history with this cafe, on the page itself.
///
/// Previously the whole diary lived in the bottom bar as a bare score chip,
/// with the note behind a long-press on the Been pill and re-ranking behind an
/// unmarked tap on the chip. Both are surfaced here, next to the thing they
/// describe. Renders nothing unless the cafe is marked Been.
class CafeYourVisitBlock extends StatefulWidget {
  const CafeYourVisitBlock({
    super.key,
    required this.cafeId,
    required this.cafeName,
    this.cafeImageUrl,
  });

  final String cafeId;
  final String cafeName;
  final String? cafeImageUrl;

  @override
  State<CafeYourVisitBlock> createState() => _CafeYourVisitBlockState();
}

class _CafeYourVisitBlockState extends State<CafeYourVisitBlock> {
  static const _brand = Color(0xFF344E41);
  static const _score = Color(0xFF3A5A40);
  static const _ink = Color(0xFF0A0F0D);
  static const _muted = Color(0xFF767574);
  static const _border = Color(0xFFE0E0E0);

  String? _note;
  bool _noteLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNote();
  }

  @override
  void didUpdateWidget(covariant CafeYourVisitBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cafeId != widget.cafeId) _loadNote();
  }

  Future<void> _loadNote() async {
    String? note;
    try {
      note = await sl<GetCafeNoteUseCase>()(widget.cafeId);
    } catch (_) {
      // The note is garnish — a read failure just leaves the quote out.
      note = null;
    }
    if (!mounted) return;
    setState(() {
      _note = note?.trim();
      _noteLoaded = true;
    });
  }

  Future<void> _openNoteSheet() async {
    await showCafeNoteSheet(
      context,
      cafeId: widget.cafeId,
      cafeName: widget.cafeName,
    );
    if (mounted) await _loadNote();
  }

  Future<void> _openRankingFlow() async {
    final outcome = await showCafeRankingFlow(
      context,
      cubit: context.read<CafeRankingCubit>(),
      cafeId: widget.cafeId,
      cafeName: widget.cafeName,
      cafeImageUrl: widget.cafeImageUrl,
    );
    if (!mounted) return;

    // The reveal's CTAs have to be honoured here too — this entry point
    // dropped the outcome, so "Add a note" off a re-rank did nothing at all.
    switch (outcome) {
      case RankingFlowOutcome.completedAddNote:
        await _openNoteSheet();
      case RankingFlowOutcome.completedViewList:
        await openBeenList(context);
      case RankingFlowOutcome.completed ||
          RankingFlowOutcome.skipped ||
          RankingFlowOutcome.failed ||
          null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CafeStatusCubit, CafeStatusState>(
      buildWhen: (previous, current) =>
          previous.statusFor(widget.cafeId) != current.statusFor(widget.cafeId),
      builder: (context, statusState) {
        if (statusState.statusFor(widget.cafeId) != CafeStatus.been) {
          return const SizedBox.shrink();
        }

        return BlocBuilder<CafeRankingCubit, CafeRankingState>(
          builder: (context, rankingState) {
            final ranking = rankingState.rankingFor(widget.cafeId);
            final overall = rankingState.overallRankOf(widget.cafeId);
            final note = _note;
            final hasNote = _noteLoaded && note != null && note.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your visit',
                      style: context.textTheme.bodySmallMed.copyWith(
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (ranking == null)
                      Text(
                        'Been — not ranked yet.',
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: _ink,
                        ),
                      )
                    else
                      // The score with its rank context, as one reading.
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: ranking.displayScore,
                              style: context.textTheme.titleLargeSemi.copyWith(
                                color: _score,
                                letterSpacing: -0.48,
                              ),
                            ),
                            if (overall != null)
                              TextSpan(
                                text:
                                    '  · #$overall of '
                                    '${rankingState.rankedCount} in your '
                                    'Been list',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: _muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (hasNote) ...[
                      const SizedBox(height: 6),
                      Text(
                        '“$note”',
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: _ink,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        _TextAction(
                          icon: PhosphorIcons.arrowsDownUp(),
                          label: ranking == null
                              ? 'Rank it · ~20 sec'
                              : 'Re-rank',
                          onTap: _openRankingFlow,
                        ),
                        const SizedBox(width: 24),
                        Flexible(
                          child: _TextAction(
                            icon: PhosphorIcons.pencilSimple(),
                            label: hasNote ? 'Edit note' : 'Add a note',
                            onTap: _openNoteSheet,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _CafeYourVisitBlockState._brand),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLargeMed.copyWith(
                  color: _CafeYourVisitBlockState._brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
