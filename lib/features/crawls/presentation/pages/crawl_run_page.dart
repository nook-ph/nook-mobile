import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/location/device_location.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/services/share_service.dart';
import 'package:nook/core/utils/geo.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/features/crawls/data/stamp_locator.dart';
import 'package:nook/features/crawls/domain/crawl_stats.dart';
import 'package:nook/features/crawls/domain/entities/crawl.dart';
import 'package:nook/features/crawls/domain/entities/crawl_exception.dart';
import 'package:nook/features/crawls/domain/entities/crawl_run.dart';
import 'package:nook/features/crawls/domain/use_cases/claim_crawl_stamp_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/enable_crawl_link_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/get_crawl_run_usecase.dart';
import 'package:nook/features/crawls/domain/use_cases/leave_crawl_run_usecase.dart';
import 'package:nook/features/crawls/presentation/cubit/crawl_run_cubit.dart';
import 'package:nook/features/crawls/presentation/cubit/my_crawls_cubit.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_complete_page.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_detail_page.dart';
import 'package:nook/features/crawls/presentation/pages/crawl_share_page.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_ui.dart';
import 'package:nook/features/crawls/presentation/widgets/crawl_widgets.dart';
import 'package:nook/features/crawls/presentation/widgets/invite_crew_sheet.dart';
import 'package:nook/features/crawls/presentation/widgets/run_options_sheet.dart';
import 'package:nook/features/crawls/presentation/widgets/stamp_sheet.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/injection_container.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The live screen of a crawl: progress, the crew, and a Stamp button at the
/// stop you are standing in.
class CrawlRunPage extends StatelessWidget {
  const CrawlRunPage({super.key, required this.runId, this.initial});

  final String runId;
  final CrawlRun? initial;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CrawlRunCubit(
        getCrawlRunUseCase: sl<GetCrawlRunUseCase>(),
        claimCrawlStampUseCase: sl<ClaimCrawlStampUseCase>(),
        leaveCrawlRunUseCase: sl<LeaveCrawlRunUseCase>(),
        locator: sl<IStampLocator>(),
        analytics: sl<AnalyticsService>(),
      )..load(runId, initial: initial),
      child: _CrawlRunView(runId: runId),
    );
  }
}

class _CrawlRunView extends StatefulWidget {
  const _CrawlRunView({required this.runId});

  final String runId;

  @override
  State<_CrawlRunView> createState() => _CrawlRunViewState();
}

/// Why the device cannot give a position right now, if it can't.
enum _LocationBlock { serviceOff, denied, deniedForever }

class _CrawlRunViewState extends State<_CrawlRunView>
    with WidgetsBindingObserver {
  /// How close the device must look before a stop reads "You're here". Only
  /// decides what the row says — the server decides whether a stamp counts.
  static const _hereMeters = 75.0;
  static const _nearMeters = 150.0;

  _LocationBlock? _locationBlock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    DeviceLocation.instance.ensure();
    _checkLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Crew progress is not realtime in v1; coming back to the app refetches.
    // It is also where the user returns from Settings after fixing location.
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<CrawlRunCubit>().refresh();
      _checkLocation();
    }
  }

  /// Reads the location switch and permission without prompting, so the
  /// banner can say so before the user is standing at the cafe.
  Future<void> _checkLocation() async {
    _LocationBlock? block;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        block = _LocationBlock.serviceOff;
      } else {
        block = switch (await Geolocator.checkPermission()) {
          LocationPermission.deniedForever => _LocationBlock.deniedForever,
          LocationPermission.denied => _LocationBlock.denied,
          _ => null,
        };
      }
    } catch (e) {
      debugPrint('[CrawlRun] location check failed: $e');
    }
    if (!mounted || block == _locationBlock) return;
    setState(() => _locationBlock = block);
    if (block == null) DeviceLocation.instance.ensure();
  }

  Future<void> _fixLocation() async {
    switch (_locationBlock) {
      case _LocationBlock.serviceOff:
        await Geolocator.openLocationSettings();
      case _LocationBlock.deniedForever:
        await Geolocator.openAppSettings();
      case _LocationBlock.denied:
        await Geolocator.requestPermission();
      case null:
        break;
    }
    if (mounted) await _checkLocation();
  }

  Future<void> _stamp(CrawlStop stop) async {
    final cubit = context.read<CrawlRunCubit>();
    if (cubit.state.isStamping) return;

    cubit.stamp(stop);
    final result = await StampSheet.show(context, cubit: cubit, stop: stop);
    cubit.clearStamp();
    if (!mounted) return;
    _checkLocation();

    if (result == StampSheetResult.gone) {
      // The crawl was removed under the run: there is nothing left to come
      // back to, so OK returns to Lists.
      context.read<MyCrawlsCubit>().load();
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    final run = cubit.state.run;
    if (run == null) return;
    if (result == StampSheetResult.shareStop) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CrawlSharePage(run: run, stampStop: stop),
        ),
      );
      if (!mounted) return;
    }
    if (run.isComplete && run.myStampFor(stop.stopId) != null) {
      _openRecap(run);
    }
  }

  void _openRecap(CrawlRun run) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CrawlCompletePage(run: run)));
  }

  void _invite(CrawlRun run) {
    InviteCrewSheet.show(
      context,
      run: run,
      onShared: context.read<CrawlRunCubit>().trackInviteShared,
    );
  }

  Future<void> _openOptions(CrawlRun run) async {
    final option = await RunOptionsSheet.show(context, run: run);
    if (!mounted || option == null) return;
    switch (option) {
      case RunOption.invite:
        _invite(run);
      case RunOption.shareLink:
        await _shareCrawl(run);
      case RunOption.viewCrawl:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CrawlDetailPage(
              shareCode: run.crawl.shareCode,
              initial: run.crawl,
            ),
          ),
        );
      case RunOption.leave:
        await _leave(run);
    }
  }

  Future<void> _shareCrawl(CrawlRun run) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await sl<EnableCrawlLinkUseCase>()(run.crawl);
      await sl<ShareService>().shareCrawl(
        shareCode: run.crawl.shareCode,
        title: run.crawl.title,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      debugPrint('[CrawlRun] share failed: $e');
      if (mounted) {
        showPrimaryToast(context, 'Couldn’t open sharing. Please try again.');
      }
    }
  }

  Future<void> _leave(CrawlRun run) async {
    final confirmed = await LeaveRunDialog.show(
      context,
      stampCount: run.myStampCount,
    );
    if (!confirmed || !mounted) return;

    final left = await context.read<CrawlRunCubit>().leave();
    if (!mounted) return;
    if (!left) {
      showPrimaryToast(context, 'Couldn’t leave the run. Please try again.');
      return;
    }
    context.read<MyCrawlsCubit>().load();
    Navigator.of(context).pop();
    showPrimaryToast(context, 'You left the run.');
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CrawlRunCubit, CrawlRunState>(
      listenWhen: (previous, current) =>
          previous.stampPhase != current.stampPhase &&
          current.stampPhase == StampPhase.stamped,
      listener: (context, state) {
        // A stamp also marks the cafe Been: bring every surface that shows
        // that up to date.
        final stop = state.stampStop;
        if (stop != null) {
          context.read<CafeStatusCubit>().loadFor([stop.cafeId]);
        }
        context.read<ListsBloc>().add(LoadUserLists());
        context.read<MyCrawlsCubit>().load();
      },
      builder: (context, state) {
        final run = state.run;
        return Scaffold(
          backgroundColor: ListsTokens.surface,
          appBar: AppBar(
            backgroundColor: ListsTokens.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: ListsTokens.surface,
            titleSpacing: 0,
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
            title: Text(
              run?.crawl.title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: crawlText(16, weight: FontWeight.w600),
            ),
            actions: [
              if (run != null && state.status == CrawlRunStatus.loaded)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AdaptiveTap(
                    onTap: state.isLeaving ? null : () => _openOptions(run),
                    borderRadius: BorderRadius.circular(22),
                    child: Semantics(
                      button: true,
                      label: 'More options',
                      child: const SizedBox.square(
                        dimension: 44,
                        child: Icon(
                          LucideIcons.ellipsis,
                          size: 22,
                          color: ListsTokens.ink,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: switch (state.status) {
            CrawlRunStatus.loading => const _RunSkeleton(),
            CrawlRunStatus.error => _errorBody(context, state.error),
            CrawlRunStatus.loaded => RefreshIndicator(
              color: ListsTokens.brand,
              onRefresh: context.read<CrawlRunCubit>().refresh,
              child: ValueListenableBuilder<Position?>(
                valueListenable: DeviceLocation.instance.position,
                builder: (context, position, _) =>
                    _body(context, run!, position),
              ),
            ),
          },
        );
      },
    );
  }

  Widget _errorBody(BuildContext context, Object? error) {
    if (error is CrawlNotFound) {
      return CrawlStateView(
        icon: CrawlStateView.goneIcon,
        title: 'This run is no longer available',
        subtitle: 'The crawl may have been removed.',
        primaryLabel: 'Back to Lists',
        onPrimary: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
      );
    }
    final info = AppErrorCopy.fromException(error ?? Exception());
    return FullPageErrorWidget(
      error: info,
      onRetry: info.type == ErrorType.sessionExpired
          ? () => context.push('/login')
          : () => context.read<CrawlRunCubit>().load(widget.runId),
    );
  }

  Widget _body(BuildContext context, CrawlRun run, Position? position) {
    final stops = run.crawl.stops;
    final done = run.myStampedStopIds;
    final next = run.nextStop;
    // A stale cached fix is worse than none while location is switched off.
    final origin = position == null || _locationBlock != null
        ? null
        : GeoPoint(lat: position.latitude, lng: position.longitude);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${run.myStampCount}/${stops.length}',
              style: crawlText(
                40,
                weight: FontWeight.w600,
                color: ListsTokens.brand,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'stops stamped',
                style: crawlText(14, color: ListsTokens.muted),
              ),
            ),
          ],
        ),
        // Figma: 14 between every block of the body.
        const SizedBox(height: 14),
        CrawlSegmentedProgress(done: run.myStampCount, total: stops.length),
        const SizedBox(height: 14),
        Row(
          children: [
            CrewAvatars(crew: run.members),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _crewLabel(run),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: crawlText(12, color: ListsTokens.muted),
              ),
            ),
            const SizedBox(width: 8),
            InviteCrewPill(onTap: () => _invite(run)),
          ],
        ),
        if (_locationBlock != null) ...[
          const SizedBox(height: 14),
          _LocationBanner(block: _locationBlock!, onAction: _fixLocation),
        ],
        // 14, plus the 4 the stop list keeps above itself.
        const SizedBox(height: 18),
        for (var i = 0; i < stops.length; i++)
          _StopRow(
            stop: stops[i],
            stamp: run.myStampFor(stops[i].stopId),
            crewStamped: run.crewStampCount(stops[i].stopId),
            crewSize: run.members.length,
            distanceMeters: origin == null
                ? null
                : haversineMeters(
                    origin,
                    GeoPoint(lat: stops[i].lat, lng: stops[i].lng),
                  ),
            isNext: stops[i].stopId == next?.stopId,
            hereMeters: _hereMeters,
            nearMeters: _nearMeters,
            // The line into a stop is "walked" once that stop is stamped.
            lineBelow: i == stops.length - 1
                ? null
                : done.contains(stops[i + 1].stopId),
            onStamp: done.contains(stops[i].stopId)
                ? null
                : () => _stamp(stops[i]),
          ),
        const SizedBox(height: 14),
        if (run.isComplete)
          CrawlPrimaryButton(
            label: 'See your recap',
            onTap: () => _openRecap(run),
          )
        else
          Text(
            'Stamps only count when you’re at the cafe.',
            textAlign: TextAlign.center,
            style: crawlText(10, color: ListsTokens.muted),
          ),
      ],
    );
  }

  static String _crewLabel(CrawlRun run) {
    if (run.members.length <= 1) return 'Solo run';
    return run.members
        .map((m) => m.isMe ? 'You' : '@${m.username ?? 'someone'}')
        .join(', ');
  }
}

/// Says location is unavailable before the user reaches a cafe, with the one
/// action that fixes it.
class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.block, required this.onAction});

  final _LocationBlock block;
  final VoidCallback onAction;

  static const _fill = crawlWarmTint;

  @override
  Widget build(BuildContext context) {
    final (title, action) = switch (block) {
      _LocationBlock.serviceOff => ('Location is off', 'Turn on'),
      _LocationBlock.denied => ('Nook needs your location', 'Allow'),
      _LocationBlock.deniedForever => (
        'Nook needs your location',
        'Open settings',
      ),
    };
    return Container(
      // Figma: 12 all round. The action carries its own 12 at the sides.
      padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(ListsTokens.radius),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.mapPin, size: 18, color: ListsTokens.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: crawlText(12, weight: FontWeight.w500)),
                Text(
                  'You need it to stamp a stop.',
                  style: crawlText(10, color: ListsTokens.muted),
                ),
              ],
            ),
          ),
          CrawlTextButton(
            label: action,
            onTap: onAction,
            fontSize: 12,
            minHeight: 33,
          ),
        ],
      ),
    );
  }
}

/// The run page's shape while the run loads.
class _RunSkeleton extends StatelessWidget {
  const _RunSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading run',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: CrawlSkeleton(width: 96, height: 40),
          ),
          const SizedBox(height: 14),
          const CrawlSkeleton(height: 6, radius: 3),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: CrawlSkeleton(width: 160, height: 28, radius: 14),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const CrawlSkeleton(width: 28, height: 28, radius: 14),
                  const SizedBox(width: 12),
                  CrawlSkeleton(width: 150.0 + (i.isEven ? 30 : 0), height: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({
    required this.stop,
    required this.stamp,
    required this.crewStamped,
    required this.crewSize,
    required this.distanceMeters,
    required this.isNext,
    required this.hereMeters,
    required this.nearMeters,
    required this.lineBelow,
    required this.onStamp,
  });

  final CrawlStop stop;
  final CrawlStamp? stamp;
  final int crewStamped;
  final int crewSize;

  /// From the device's last known position; null when location is unknown.
  final double? distanceMeters;
  final bool isNext;
  final double hereMeters;
  final double nearMeters;
  final bool? lineBelow;
  final VoidCallback? onStamp;

  bool get _stamped => stamp != null;

  bool get _here =>
      !_stamped && distanceMeters != null && distanceMeters! <= hereMeters;

  /// The button shows on the next stop always (so a missing fix never hides
  /// the only way forward) and on any stop the device looks close to.
  bool get _showStamp =>
      !_stamped &&
      (isNext || (distanceMeters != null && distanceMeters! <= nearMeters));

  @override
  Widget build(BuildContext context) {
    return CrawlRouteRow(
      lineBelow: lineBelow,
      marker: _stamped
          ? const CrawlSeal(size: 28, color: ListsTokens.score)
          : CrawlNumberBadge(
              number: stop.order,
              size: 28,
              outlined: !_here && !isNext,
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                Text(
                  _meta(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: crawlText(
                    12,
                    color: _here ? ListsTokens.brand : ListsTokens.muted,
                  ),
                ),
              ],
            ),
          ),
          if (_showStamp) ...[
            const SizedBox(width: 12),
            // Figma: a 36 pill at the top of the row.
            CrawlPillButton(label: 'Stamp', onTap: onStamp, tapHeight: 36),
          ],
        ],
      ),
    );
  }

  String _meta() {
    final stamped = stamp;
    if (stamped != null) {
      final time = CrawlStats.formatClock(stamped.claimedAt);
      return crewSize > 1
          ? 'Stamped $time · $crewStamped of $crewSize crew'
          : 'Stamped $time';
    }
    final distance = distanceMeters;
    if (distance == null) return stop.neighborhood ?? 'Not stamped yet';
    final label = CrawlStats.formatDistance(distance);
    return _here ? 'You’re here · $label' : '$label away';
  }
}
