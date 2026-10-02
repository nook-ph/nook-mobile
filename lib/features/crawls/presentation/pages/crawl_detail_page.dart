import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/services/share_service.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/crawls/domain/crawl_stats.dart';
import 'package:nook/features/crawls/domain/use_cases/enable_crawl_link_usecase.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/use_cases/archive_crawl_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_by_code_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/start_crawl_run_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_detail_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/my_crawls_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/report_crawl_cubit.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_run_page.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_options_sheet.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_sign_in_sheet.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_route_map.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/crawls/presentation/widgets/edit_crawl_title_sheet.dart';
import 'package:nook/features/crawls/presentation/widgets/report_crawl_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/injection_container.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A crawl before you start it: the stops, the route, and "Start a run".
class CrawlDetailPage extends StatelessWidget {
  const CrawlDetailPage({super.key, required this.shareCode, this.initial});

  final String shareCode;

  /// When the caller already holds the crawl, it is shown at once and
  /// refreshed in the background.
  final Crawl? initial;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CrawlDetailCubit(
        getCrawlByCodeUseCase: sl<GetCrawlByCodeUseCase>(),
        startCrawlRunUseCase: sl<StartCrawlRunUseCase>(),
        archiveCrawlUseCase: sl<ArchiveCrawlUseCase>(),
        analytics: sl<AnalyticsService>(),
      )..load(shareCode, initial: initial),
      child: _CrawlDetailView(shareCode: shareCode),
    );
  }
}

class _CrawlDetailView extends StatelessWidget {
  const _CrawlDetailView({required this.shareCode});

  final String shareCode;

  /// Lifts toasts clear of the sticky "Start a run" bar.
  static const _barHeight = 72.0;

  void _toast(BuildContext context, String message) {
    showPrimaryToast(context, message, bottomOffset: _barHeight);
  }

  Future<void> _share(BuildContext context, Crawl crawl) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await sl<EnableCrawlLinkUseCase>()(crawl);
      await sl<ShareService>().shareCrawl(
        shareCode: crawl.shareCode,
        title: crawl.title,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      debugPrint('[CrawlDetail] share failed: $e');
      if (context.mounted) {
        _toast(context, 'Couldn’t open sharing. Please try again.');
      }
    }
  }

  Future<void> _openOptions(BuildContext context, Crawl crawl) async {
    final option = await CrawlOptionsSheet.show(context, crawl);
    if (option == null || !context.mounted) return;
    switch (option) {
      case CrawlOption.share:
        await _share(context, crawl);
      case CrawlOption.editTitle:
        await _editTitle(context, crawl);
      case CrawlOption.archive:
        await _confirmArchive(context);
      case CrawlOption.report:
        await _report(context, crawl);
    }
  }

  Future<void> _editTitle(BuildContext context, Crawl crawl) async {
    final updated = await EditCrawlTitleSheet.show(context, crawl);
    if (updated == null || !context.mounted) return;
    context.read<CrawlDetailCubit>().replaceCrawl(updated);
    context.read<MyCrawlsCubit>().load();
    _toast(context, 'Title updated.');
  }

  Future<void> _report(BuildContext context, Crawl crawl) async {
    if (Supabase.instance.client.auth.currentSession == null) {
      await CrawlSignInSheet.show(
        context,
        title: 'Sign in to report this crawl',
        message: 'Reports are tied to an account so they can be reviewed.',
      );
      return;
    }
    if (ReportCrawlCubit.alreadyReported(crawl.id)) {
      _toast(context, 'You already reported this crawl.');
      return;
    }
    final sent = await ReportCrawlSheet.show(context, crawl);
    if (sent != true || !context.mounted) return;
    showPrimaryToast(
      context,
      'Thanks for reporting. Our team reviews reports within 24 hours.',
      bottomOffset: _barHeight,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _confirmArchive(BuildContext context) async {
    final cubit = context.read<CrawlDetailCubit>();
    final confirmed = await CrawlConfirmDialog.show(
      context,
      title: 'Archive this crawl?',
      body:
          'Nobody will be able to start it again. Runs already under way '
          'keep working.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Archive',
    );
    if (confirmed) await cubit.archive();
  }

  Future<void> _startRun(BuildContext context) async {
    if (Supabase.instance.client.auth.currentSession == null) {
      await CrawlSignInSheet.show(
        context,
        title: 'Sign in to start this crawl',
        message: 'Stamps are saved to your account, so a run needs one.',
      );
      return;
    }
    await context.read<CrawlDetailCubit>().startRun();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CrawlDetailCubit, CrawlDetailState>(
      listenWhen: (previous, current) =>
          previous.startedRun != current.startedRun ||
          previous.archived != current.archived ||
          (current.error != null && previous.error != current.error),
      listener: (context, state) {
        final run = state.startedRun;
        if (run != null) {
          context.read<CrawlDetailCubit>().consumeStartedRun();
          context.read<MyCrawlsCubit>().load();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CrawlRunPage(runId: run.id, initial: run),
            ),
          );
          return;
        }
        if (state.archived && state.error == null) {
          context.read<MyCrawlsCubit>().load();
          _toast(context, 'Crawl archived.');
          return;
        }
        if (state.error != null && state.status == CrawlDetailStatus.loaded) {
          final info = AppErrorCopy.fromException(state.error!);
          _toast(
            context,
            state.error is CrawlNotFound
                ? 'This crawl is no longer available.'
                : '${info.title} · ${info.subtitle}',
          );
        }
      },
      builder: (context, state) {
        final crawl = state.crawl;
        final loaded =
            state.status == CrawlDetailStatus.loaded && crawl != null;
        return Scaffold(
          backgroundColor: ListsTokens.surface,
          appBar: AppBar(
            backgroundColor: ListsTokens.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: ListsTokens.surface,
            leading: AdaptiveTap(
              onTap: () => Navigator.of(context).pop(),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  LucideIcons.arrowLeft,
                  size: 24,
                  color: ListsTokens.ink,
                ),
              ),
            ),
            actions: [
              if (loaded) ...[
                Builder(
                  builder: (buttonContext) => IconButton(
                    tooltip: 'Share crawl link',
                    onPressed: () => _share(buttonContext, crawl),
                    icon: const Icon(
                      LucideIcons.share,
                      color: ListsTokens.ink,
                      size: 22,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'More options',
                  onPressed: () => _openOptions(context, crawl),
                  icon: const Icon(
                    LucideIcons.ellipsis,
                    color: ListsTokens.ink,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ],
          ),
          body: switch (state.status) {
            CrawlDetailStatus.loading => const _LoadingBody(),
            CrawlDetailStatus.error => _ErrorBody(
              error: state.error,
              onRetry: () => context.read<CrawlDetailCubit>().load(shareCode),
            ),
            CrawlDetailStatus.loaded => _Body(crawl: crawl!),
          },
          bottomNavigationBar: !loaded
              ? null
              : DecoratedBox(
                  decoration: const BoxDecoration(
                    color: ListsTokens.surface,
                    border: Border(top: BorderSide(color: ListsTokens.border)),
                  ),
                  child: SafeArea(
                    minimum: const EdgeInsets.fromLTRB(
                      crawlGutter,
                      12,
                      crawlGutter,
                      8,
                    ),
                    child: CrawlPrimaryButton(
                      label: crawl.isArchived
                          ? 'Archived'
                          : (state.starting ? 'Starting…' : 'Start a run'),
                      onTap: crawl.isArchived || state.busy
                          ? null
                          : () => _startRun(context),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// The page's own shape in grey while the crawl loads (Figma 1605:44712).
class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    Widget left(Widget child) =>
        Align(alignment: Alignment.centerLeft, child: child);
    return Semantics(
      label: 'Loading crawl',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(crawlGutter, 8, crawlGutter, 0),
        children: [
          left(const CrawlSkeleton(width: 60, height: 20, radius: 10)),
          const SizedBox(height: 14),
          left(const CrawlSkeleton(width: 240, height: 26, radius: 8)),
          const SizedBox(height: 14),
          left(const CrawlSkeleton(width: 180, height: 14, radius: 7)),
          const SizedBox(height: 14),
          const CrawlSkeleton(height: 118, radius: ListsTokens.radius),
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  CrawlSkeleton(width: 28, height: 28, radius: 14),
                  SizedBox(width: 12),
                  CrawlSkeleton(width: 40, height: 40, radius: 8),
                  SizedBox(width: 12),
                  CrawlSkeleton(width: 170, height: 14, radius: 7),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  /// Figma: the state block starts 170 below the nav on this page.
  static const _top = 170.0;

  @override
  Widget build(BuildContext context) {
    if (error is CrawlNotFound) {
      // The page is reached from a typed code or a link; going back returns
      // to wherever the code was entered.
      return CrawlStateView(
        top: _top,
        icon: CrawlStateView.alertIcon,
        title: "We couldn't find that crawl",
        subtitle: 'Check the code, or ask for a fresh link.',
        primaryLabel: 'Enter a different code',
        onPrimary: () => Navigator.of(context).pop(),
      );
    }
    final info = AppErrorCopy.fromException(error ?? Exception());
    final signedOut = info.type == ErrorType.sessionExpired;
    return CrawlStateView(
      top: _top,
      icon: switch (info.type) {
        ErrorType.offline => CrawlStateView.offlineIcon,
        ErrorType.sessionExpired => CrawlStateView.lockedIcon,
        _ => CrawlStateView.alertIcon,
      },
      title: info.title,
      subtitle: info.subtitle,
      primaryLabel: signedOut ? 'Sign in' : 'Try again',
      primaryFilled: signedOut,
      onPrimary: signedOut ? () => context.push('/login') : onRetry,
      secondaryLabel: 'Back to Lists',
      onSecondary: () => Navigator.of(context).pop(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.crawl});

  final Crawl crawl;

  @override
  Widget build(BuildContext context) {
    final distance = CrawlStats.routeDistanceMeters(crawl.stops);
    final area = _areaLabel(crawl);
    final stops = crawl.stops;

    // Figma: 12 between every block of the body.
    const gap = SizedBox(height: 12);

    return ListView(
      padding: const EdgeInsets.fromLTRB(crawlGutter, 4, crawlGutter, 24),
      children: [
        Row(
          children: [
            const CrawlChip(label: 'Crawl'),
            if (crawl.isArchived) ...[
              const SizedBox(width: 6),
              const CrawlChip(label: 'Archived', neutral: true),
            ],
          ],
        ),
        gap,
        Text(crawl.title, style: crawlText(24, weight: FontWeight.w600)),
        gap,
        Row(
          children: [
            _CreatorAvatar(crawl: crawl),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                [
                  crawl.isCreator ? 'by you' : crawl.byline,
                  '${stops.length} stops',
                  ?area,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: crawlText(12, color: ListsTokens.muted),
              ),
            ),
          ],
        ),
        gap,
        CrawlRouteMap(stops: stops),
        gap,
        _StatsRow(
          stats: [
            ('${crawl.runsStarted}', crawl.runsStarted == 1 ? 'run' : 'runs'),
            ('${crawl.completions}', 'finished'),
            (CrawlStats.formatDistance(distance), 'between stops'),
          ],
        ),
        gap,
        const Divider(height: 1, color: ListsTokens.border),
        gap,
        for (var i = 0; i < stops.length; i++)
          CrawlRouteRow(
            lineBelow: i == stops.length - 1 ? null : false,
            marker: CrawlNumberBadge(
              number: stops[i].order,
              size: 28,
              outlined: true,
            ),
            child: _StopRow(stop: stops[i]),
          ),
      ],
    );
  }

  /// The neighbourhood, only when every stop shares it.
  static String? _areaLabel(Crawl crawl) {
    final areas = crawl.stops
        .map((s) => s.neighborhood?.trim() ?? '')
        .where((n) => n.isNotEmpty)
        .toSet();
    return areas.length == 1 ? areas.first : null;
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.stop});

  final CrawlStop stop;

  @override
  Widget build(BuildContext context) {
    final area = stop.neighborhood ?? '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CrawlStopThumb(imageUrl: stop.imageUrl, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stop.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: crawlText(14, weight: FontWeight.w500),
              ),
              if (area.isNotEmpty)
                Text(
                  area,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: crawlText(12, color: ListsTokens.muted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The creator's photo, or their initial on the brand colour.
///
/// Figma: a 24 box whose 2pt ring is the page colour, so the disc reads 20.
class _CreatorAvatar extends StatelessWidget {
  const _CreatorAvatar({required this.crawl});

  final Crawl crawl;

  static const _size = 24.0;

  @override
  Widget build(BuildContext context) {
    final name = crawl.creatorUsername?.trim() ?? '';
    final initial = Container(
      color: ListsTokens.brand,
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: ListsTokens.surface,
          height: 1,
        ),
      ),
    );
    final url = crawl.creatorAvatarUrl?.trim() ?? '';
    return ExcludeSemantics(
      child: Container(
        width: _size,
        height: _size,
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: ListsTokens.surface,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: url.isEmpty
              ? initial
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => initial,
                  errorWidget: (_, _, _) => initial,
                ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0)
            const SizedBox(
              width: 1,
              height: 28,
              child: ColoredBox(color: ListsTokens.border),
            ),
          Expanded(
            child: Column(
              children: [
                Text(
                  stats[i].$1,
                  style: crawlText(16, weight: FontWeight.w600),
                ),
                Text(
                  stats[i].$2,
                  style: crawlText(10, color: ListsTokens.muted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
