import 'package:flutter/material.dart';
import 'package:nook/features/crawls/domain/crawl_stats.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_share_page.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The end of a crawl: the seal, three numbers, and the way to share them.
class CrawlCompletePage extends StatelessWidget {
  const CrawlCompletePage({super.key, required this.run});

  final CrawlRun run;

  @override
  Widget build(BuildContext context) {
    final stops = run.crawl.stops;
    final elapsed = CrawlStats.elapsed(run);
    final crew = run.members.where((m) => !m.isMe).toList();

    // Figma: 10 between every block; a spacer adds to it where noted.
    const gap = SizedBox(height: 10);

    return Scaffold(
      backgroundColor: ListsTokens.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(crawlGutter, 36, crawlGutter, 24),
          children: [
            const Center(child: CrawlSeal(size: 120, ring: true)),
            // 10 + a 6 spacer + 10.
            const SizedBox(height: 26),
            Text(
              'Crawl complete',
              textAlign: TextAlign.center,
              style: crawlText(24, weight: FontWeight.w600),
            ),
            gap,
            Text(
              '${run.crawl.title} · ${run.crawl.byline}',
              textAlign: TextAlign.center,
              style: crawlText(14, color: ListsTokens.muted),
            ),
            const SizedBox(height: 26),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(ListsTokens.radius),
                border: Border.all(color: ListsTokens.border),
              ),
              child: Row(
                children: [
                  _Stat(
                    value: '${run.myStampCount}/${stops.length}',
                    label: 'Stops',
                  ),
                  const _StatDivider(),
                  _Stat(
                    value: CrawlStats.formatDistance(
                      CrawlStats.routeDistanceMeters(stops),
                    ),
                    label: 'Distance',
                  ),
                  if (elapsed != null) ...[
                    const _StatDivider(),
                    _Stat(
                      value: CrawlStats.formatDuration(elapsed),
                      label: 'Time',
                    ),
                  ],
                ],
              ),
            ),
            // 10 + a 4 spacer + 10.
            const SizedBox(height: 24),
            // One seal per stop: the same marks the run page handed out.
            Semantics(
              label: '${run.myStampCount} of ${stops.length} stops stamped',
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final stop in stops)
                    run.myStampFor(stop.stopId) != null
                        ? CrawlSeal(
                            size: 44,
                            label: '${stop.order}',
                            ring: true,
                          )
                        : CrawlNumberBadge(
                            number: stop.order,
                            size: 44,
                            outlined: true,
                          ),
                ],
              ),
            ),
            gap,
            Text(
              elapsed == null
                  ? 'Between stops, straight line.'
                  : 'Between stops, straight line. Time is first stamp to last.',
              textAlign: TextAlign.center,
              style: crawlText(10, color: ListsTokens.muted),
            ),
            if (crew.isNotEmpty) ...[
              // 10 + a 2 spacer + 10.
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CrewAvatars(crew: run.members),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'with ${crew.map((m) => '@${m.username ?? 'someone'}').join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: crawlText(12, color: ListsTokens.muted),
                    ),
                  ),
                ],
              ),
            ],
            gap,
            Center(
              child: CrawlChip(label: '${stops.length} cafes added to Been'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(crawlGutter, 12, crawlGutter, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CrawlPrimaryButton(
              label: 'Share',
              icon: LucideIcons.share,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CrawlSharePage(run: run)),
              ),
            ),
            const SizedBox(height: 6),
            CrawlTextButton(
              label: 'Done',
              color: ListsTokens.muted,
              minHeight: 40,
              // Back to wherever the crawl was opened from, past the run page.
              onTap: () => Navigator.of(context)
                ..pop()
                ..pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 1,
    height: 32,
    child: ColoredBox(color: ListsTokens.border),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: crawlText(20, weight: FontWeight.w600)),
          Text(label, style: crawlText(10, color: ListsTokens.muted)),
        ],
      ),
    );
  }
}
