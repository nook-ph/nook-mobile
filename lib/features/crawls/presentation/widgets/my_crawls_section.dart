import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/presentation/cubit/my_crawls_cubit.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_detail_page.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_run_page.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/crawls/presentation/widgets/enter_crawl_code_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The Crawls block on the Lists tab: runs in progress first, then finished
/// runs, then crawls the user made. With nothing to show it explains how to
/// make one instead of rendering an empty heading.
class MyCrawlsSection extends StatelessWidget {
  const MyCrawlsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyCrawlsCubit, MyCrawlsState>(
      builder: (context, state) {
        final crawls = state.crawls;
        final active = crawls.runs.where((r) => !r.isComplete).toList();
        final finished = crawls.runs.where((r) => r.isComplete).toList();

        // Anything already on screen stays while a reload runs or fails.
        final loading =
            crawls.isEmpty &&
            (state.status == MyCrawlsStatus.initial ||
                state.status == MyCrawlsStatus.loading);
        final failed = crawls.isEmpty && state.status == MyCrawlsStatus.error;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Figma "Crawls header": 8 above, then 12 to the first card.
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Crawls',
                      style: crawlText(16, weight: FontWeight.w600),
                    ),
                  ),
                  Transform.translate(
                    // Keeps the 44pt target while the label sits on the
                    // gutter.
                    offset: const Offset(12, 0),
                    child: CrawlTextButton(
                      label: 'Enter a code',
                      fontSize: 12,
                      onTap: () => EnterCrawlCodeSheet.show(context),
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              const _LoadingCards()
            else if (failed)
              _ErrorCard(onRetry: context.read<MyCrawlsCubit>().load)
            else if (crawls.isEmpty)
              const _EmptyCard()
            else ...[
              for (final run in active) ...[
                _ActiveRunCard(run: run),
                const SizedBox(height: _gap),
              ],
              for (final run in finished) ...[
                _FinishedRunRow(run: run),
                const SizedBox(height: _gap),
              ],
              if (crawls.created.isNotEmpty) ...[
                if (crawls.runs.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: _gap),
                    child: Text(
                      'Made by you',
                      style: crawlText(12, color: ListsTokens.muted),
                    ),
                  ),
                for (final crawl in crawls.created) ...[
                  _CreatedCrawlRow(crawl: crawl, labelled: crawls.runs.isEmpty),
                  const SizedBox(height: _gap),
                ],
              ],
            ],
          ],
        );
      },
    );
  }
}

/// Figma: 12 between every card and label of the block.
const _gap = 12.0;

BoxDecoration _cardDecoration() => BoxDecoration(
  color: ListsTokens.surface,
  borderRadius: BorderRadius.circular(ListsTokens.radius),
  border: Border.all(color: ListsTokens.border),
);

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crawlSoftFill,
        borderRadius: BorderRadius.circular(ListsTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No crawls yet', style: crawlText(14, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Turn any list with 3 or more cafes into a crawl. Open the list '
            'and tap ⋯.',
            style: crawlText(12, color: ListsTokens.muted),
          ),
        ],
      ),
    );
  }
}

/// Two cards in the shape of a run card, so the block does not jump when the
/// crawls arrive.
class _LoadingCards extends StatelessWidget {
  const _LoadingCards();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your crawls',
      child: Column(
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(height: _gap),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: _cardDecoration(),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CrawlSkeleton(width: 180, height: 14, radius: 7),
                  SizedBox(height: 10),
                  CrawlSkeleton(width: 110, height: 10, radius: 5),
                  SizedBox(height: 10),
                  CrawlSkeleton(height: 6, radius: 3),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Couldn't load your crawls",
            style: crawlText(14, weight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            'Check your connection and try again.',
            style: crawlText(12, color: ListsTokens.muted),
          ),
          const SizedBox(height: 10),
          CrawlPillButton(
            label: 'Try again',
            onTap: onRetry,
            outlined: true,
            tapHeight: 36,
          ),
        ],
      ),
    );
  }
}

void _openRun(BuildContext context, CrawlRunSummary run) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => CrawlRunPage(runId: run.runId)));
}

class _ActiveRunCard extends StatelessWidget {
  const _ActiveRunCard({required this.run});

  final CrawlRunSummary run;

  /// "with @mika, @jo": the crew other than the caller.
  ///
  /// The run summary does not say which member is the caller, so a crew of
  /// one (always the caller) reads "Solo run" rather than "with @me".
  String? get _crewLabel {
    if (run.crew.length <= 1) return 'Solo run';
    final others = run.crew
        .where((m) => !m.isMe && (m.username ?? '').isNotEmpty)
        .map((m) => '@${m.username}')
        .toList();
    return others.isEmpty ? null : 'with ${others.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final crewLabel = _crewLabel;

    return AdaptiveTap(
      onTap: () => _openRun(context, run),
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    run.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: crawlText(14, weight: FontWeight.w500),
                  ),
                ),
                const SizedBox(width: 8),
                const CrawlChip(label: 'In progress'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              [
                if (run.creatorUsername != null) 'by @${run.creatorUsername}',
                '${run.myStamps} of ${run.stopCount} stamped',
              ].join(' · '),
              style: crawlText(12, color: ListsTokens.muted),
            ),
            const SizedBox(height: 10),
            CrawlSegmentedProgress(done: run.myStamps, total: run.stopCount),
            const SizedBox(height: 10),
            Row(
              children: [
                if (run.crew.length > 1) ...[
                  CrewAvatars(crew: run.crew),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: crewLabel == null
                      ? const SizedBox.shrink()
                      : Text(
                          crewLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: crawlText(12, color: ListsTokens.muted),
                        ),
                ),
                const SizedBox(width: 8),
                // Decorative: the whole card is the tap target.
                ExcludeSemantics(
                  child: IgnorePointer(
                    child: CrawlPillButton(
                      label: 'Continue',
                      onTap: () {},
                      height: 34,
                      tapHeight: 34,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishedRunRow extends StatelessWidget {
  const _FinishedRunRow({required this.run});

  final CrawlRunSummary run;

  @override
  Widget build(BuildContext context) {
    return _Row(
      title: run.title,
      meta: [
        if (run.creatorUsername != null) 'by @${run.creatorUsername}',
        '${run.stopCount} stops',
      ].join(' · '),
      chip: const CrawlChip(label: 'Finished', neutral: true),
      onTap: () => _openRun(context, run),
    );
  }
}

class _CreatedCrawlRow extends StatelessWidget {
  const _CreatedCrawlRow({required this.crawl, required this.labelled});

  final Crawl crawl;

  /// Says "Made by you" on the row itself, for when the group has no heading.
  final bool labelled;

  @override
  Widget build(BuildContext context) {
    return _Row(
      title: crawl.title,
      meta: [
        if (labelled) 'Made by you',
        '${crawl.stops.length} stops',
        if (crawl.isArchived)
          'Archived'
        else ...[
          '${crawl.runsStarted} ${crawl.runsStarted == 1 ? 'run' : 'runs'}',
          '${crawl.completions} finished',
        ],
      ].join(' · '),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CrawlDetailPage(shareCode: crawl.shareCode, initial: crawl),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.meta,
    required this.onTap,
    this.chip,
  });

  final String title;
  final String meta;
  final VoidCallback onTap;
  final Widget? chip;

  @override
  Widget build(BuildContext context) {
    final trailing = chip;
    return AdaptiveTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ListsTokens.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: crawlText(14, weight: FontWeight.w500),
                  ),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: crawlText(10, color: ListsTokens.muted),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: ListsTokens.muted,
            ),
          ],
        ),
      ),
    );
  }
}
