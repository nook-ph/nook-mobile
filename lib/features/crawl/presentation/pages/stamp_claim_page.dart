import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:nook/core/cafe/data/cafe_remote_data_source.dart';
import 'package:nook/core/cache/custom_cache_manager.dart';
import 'package:nook/core/presentation/widgets/app_bar_circle_icon_button.dart';
import 'package:nook/features/crawl/domain/entities/crawl_detail.dart';
import 'package:nook/features/crawl/domain/entities/crawl_stop.dart';
import 'package:nook/features/crawl/domain/entities/stamp_claim_result.dart';
import 'package:nook/features/crawl/domain/use_cases/get_crawl_detail_usecase.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_bloc.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_event.dart';
import 'package:nook/features/crawl/presentation/bloc/crawl_claim_state.dart';
import 'package:nook/features/crawl/presentation/cubit/share_card_cubit.dart';
import 'package:nook/features/crawl/presentation/pages/share_cafe_stop_page.dart';
import 'package:nook/features/crawl/presentation/widgets/stamp_awarded_overlay.dart';
import 'package:nook/features/crawl/presentation/widgets/share_card_view.dart';
import 'package:nook/features/crawl/presentation/widgets/tier_completion_modal.dart';
import 'package:nook/injection_container.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';

class StampClaimPage extends StatefulWidget {
  final String crawlSlug;
  final String stopId;
  final CrawlClaimBloc? bloc;
  final GetCrawlDetailUseCase? getCrawlDetailUseCase;
  final CafeRemoteDataSource? cafeRemoteDataSource;

  const StampClaimPage({
    super.key,
    required this.crawlSlug,
    required this.stopId,
    this.bloc,
    this.getCrawlDetailUseCase,
    this.cafeRemoteDataSource,
  });

  @override
  State<StampClaimPage> createState() => _StampClaimPageState();
}

class _StampClaimPageState extends State<StampClaimPage>
    with SingleTickerProviderStateMixin {
  late final CrawlClaimBloc _bloc;
  late final ShareCardCubit _shareCardCubit;
  final _shareCardKey = GlobalKey();
  late final GetCrawlDetailUseCase? _getCrawlDetailUseCase;
  late final CafeRemoteDataSource? _cafeRemoteDataSource;

  bool _isDataLoading = true;
  String? _dataError;
  CrawlDetail? _crawlDetail;
  CrawlStop? _crawlStop;
  String? _cafePhotoUrl;
  String? _neighborhood;
  bool _showStampAnimation = false;
  int _claimedStopOrder = 0;
  Timer? _overlayTimer;

  late final AnimationController _gpsSpinController;
  late final Animation<double> _gpsSpinAnimation;

  @override
  void initState() {
    super.initState();
    _bloc = widget.bloc ?? sl<CrawlClaimBloc>();
    _shareCardCubit = sl<ShareCardCubit>();
    _getCrawlDetailUseCase = widget.getCrawlDetailUseCase;
    _cafeRemoteDataSource = widget.cafeRemoteDataSource;

    _gpsSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _gpsSpinAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _gpsSpinController, curve: Curves.linear),
    );

    _loadPageData();
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _gpsSpinController.dispose();
    super.dispose();
  }

  GetCrawlDetailUseCase _resolveGetDetail() {
    if (_getCrawlDetailUseCase != null) return _getCrawlDetailUseCase;
    try {
      return sl<GetCrawlDetailUseCase>();
    } catch (_) {
      throw Exception('GetCrawlDetailUseCase not available');
    }
  }

  CafeRemoteDataSource? _resolveCafeDS() {
    if (_cafeRemoteDataSource != null) return _cafeRemoteDataSource;
    try {
      return sl<CafeRemoteDataSource>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPageData() async {
    try {
      final useCase = _resolveGetDetail();
      final result = await useCase.call(widget.crawlSlug);
      switch (result) {
        case Right(value: final detail):
          final stop = detail.stops
              .where((CrawlStop s) => s.id == widget.stopId)
              .firstOrNull;
          if (stop == null) {
            setState(() {
              _dataError = 'Stop not found';
              _isDataLoading = false;
            });
            return;
          }

          String? photoUrl;
          String? neighborhood;
          final cafeDS = _resolveCafeDS();
          if (cafeDS != null) {
            try {
              final cafeDetails = await cafeDS.fetchDetailsById(stop.cafeId);
              photoUrl = cafeDetails.featuredImageUrl;
              neighborhood = cafeDetails.neighborhood;
            } catch (_) {}
          }

          if (!mounted) return;
          setState(() {
            _crawlDetail = detail;
            _crawlStop = stop;
            _cafePhotoUrl = photoUrl;
            _neighborhood = neighborhood;
            _isDataLoading = false;
          });

          _shareCardCubit.setShareCardKey(_shareCardKey);
          _shareCardCubit.loadData(detail.crawl.id);

          _bloc.add(
            ClaimInitialized(
              crawlId: detail.crawl.id,
              stopId: widget.stopId,
              crawlTitle: detail.crawl.title,
              cafeName: stop.cafeName,
            ),
          );

        case Left(value: final failure):
          if (!mounted) return;
          setState(() {
            _dataError = failure.message;
            _isDataLoading = false;
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dataError = e.toString();
        _isDataLoading = false;
      });
    }
  }

  void _onRetryLoad() {
    setState(() {
      _isDataLoading = true;
      _dataError = null;
    });
    _loadPageData();
  }

  void _onRetryClaim() {
    _bloc.add(ClaimRetryRequested());
    _bloc.add(
      ClaimInitialized(
        crawlId: widget.crawlSlug,
        stopId: widget.stopId,
        crawlTitle: _crawlDetail?.crawl.title ?? '',
        cafeName: _crawlStop?.cafeName ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ShareCardCubit>.value(
      value: _shareCardCubit,
      child: BlocProvider<CrawlClaimBloc>.value(
        value: _bloc,
        child: BlocConsumer<CrawlClaimBloc, CrawlClaimState>(
        listener: (context, state) {
          switch (state) {
            case ClaimSuccess(:final result):
              _claimedStopOrder = result.stamp.stopOrder;
              setState(() => _showStampAnimation = true);

            case ClaimSuccessWithTierCompletion(
                :final result,
                :final tier
              ):
              _claimedStopOrder = result.stamp.stopOrder;
              setState(() => _showStampAnimation = true);
              _overlayTimer = Timer(const Duration(milliseconds: 1500), () {
                if (mounted) _showTierCompletionSheet(context, tier);
              });

            case AcquiringGps():
              _gpsSpinController.repeat();

            default:
              if (_gpsSpinController.isAnimating) {
                _gpsSpinController.stop();
              }
          }
        },
        builder: (context, state) {
          final colors = Theme.of(context).colorScheme;
          final textTheme = Theme.of(context).textTheme;

          if (_isDataLoading) {
            return _buildLoading(context);
          }
          if (_dataError != null) {
            return _buildDataError(context);
          }
          if (_crawlDetail == null || _crawlStop == null) {
            return _buildDataError(context);
          }

          return Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Stack(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final photoHeight = constraints.maxHeight * 0.45;
                      return Column(
                        children: [
                          SizedBox(
                            height: photoHeight,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: _buildCafePhoto(colors),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height: 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.white,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  left: 22,
                                  child: AppBarCircleIconButton(
                                    icon: Icons.arrow_back,
                                    iconSize: 18,
                                    onTap: () => Navigator.pop(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _crawlStop!.cafeName,
                                    style: textTheme.titleLargeSemi.copyWith(
                                      color: colors.primary100,
                                    ),
                                  ),
                                  const Gap(4),
                                  Text(
                                    _neighborhood ?? _crawlStop!.cafeAddress,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: colors.gray,
                                    ),
                                  ),
                                  const Gap(12),
                                  _StopChip(
                                    stopOrder: _crawlStop!.stopOrder,
                                    tier: _crawlStop!.tier,
                                  ),
                                  const Gap(12),
                                  Row(
                                    children: [
                                      Icon(
                                        LucideIcons.map,
                                        size: 16,
                                        color: colors.primary60,
                                      ),
                                      const Gap(6),
                                      Text(
                                        'Part of ${_crawlDetail!.crawl.title}',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: colors.primary60,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Gap(20),
                                  _buildGpsRow(state, colors, textTheme),
                                  const Gap(24),
                                  _buildActionArea(context, state, colors, textTheme),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (_showStampAnimation)
                    StampAwardedOverlay(
                      stopOrder: _claimedStopOrder,
                      onClose: _onOverlayClose,
                      onShare: _navigateToShare,
                    ),
                  Positioned(
                    left: -9999, top: 0,
                    child: RepaintBoundary(
                      key: _shareCardKey,
                      child: const ShareCardView(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildDataError(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 22.0),
          child: AppBarCircleIconButton(
            icon: Icons.arrow_back,
            iconSize: 18,
            onTap: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.triangleAlert, size: 48, color: colors.warning),
              const Gap(16),
              Text(
                _dataError ?? 'Something went wrong',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: colors.gray),
              ),
              const Gap(24),
              ElevatedButton(
                onPressed: _onRetryLoad,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary100,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCafePhoto(ColorScheme colors) {
    final imageUrl = _cafePhotoUrl ??
        _crawlDetail?.crawl.coverImageUrl ??
        '';

    if (imageUrl.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.primary20, colors.primary40],
          ),
        ),
        child: Center(
          child: Icon(LucideIcons.image, size: 48, color: colors.primary40),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: CustomCacheManager.instance,
      fit: BoxFit.cover,
      errorWidget: (_, _, _) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.primary20, colors.primary40],
          ),
        ),
        child: Center(
          child: Icon(LucideIcons.image, size: 48, color: colors.primary40),
        ),
      ),
      placeholder: (_, _) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.primary20, colors.primary40],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsRow(
    CrawlClaimState state,
    ColorScheme colors,
    TextTheme textTheme,
  ) {
    final isAcquiring = state is AcquiringGps;
    final isVerified = state is ClaimSubmitting ||
        state is ClaimSuccess ||
        state is ClaimSuccessWithTierCompletion ||
        state is AlreadyClaimed;

    final isError = state is GpsDenied || state is GpsTimeout;

    Widget icon;
    if (isAcquiring) {
      icon = AnimatedBuilder(
        animation: _gpsSpinAnimation,
        builder: (_, child) => Transform.rotate(
          angle: _gpsSpinAnimation.value * 2 * 3.1415927,
          child: child,
        ),
        child: Icon(LucideIcons.loader, size: 20, color: colors.gray),
      );
    } else if (isVerified) {
      icon = Icon(LucideIcons.circleCheckBig, size: 20, color: colors.success);
    } else if (isError) {
      icon = Icon(LucideIcons.mapPinOff, size: 20, color: colors.error);
    } else {
      icon = Icon(LucideIcons.loader, size: 20, color: colors.gray);
    }

    String label;
    Color labelColor;
    if (isAcquiring) {
      label = 'Acquiring GPS...';
      labelColor = colors.gray;
    } else if (isVerified) {
      label = 'GPS Verified';
      labelColor = colors.success;
    } else if (isError) {
      label = 'Enable location access in Settings';
      labelColor = colors.error;
    } else {
      label = 'Acquiring GPS...';
      labelColor = colors.gray;
    }

    return Row(
      children: [
        SizedBox(width: 20, height: 20, child: icon),
        const Gap(8),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
          ),
        ),
        if (isError)
          GestureDetector(
            onTap: () => Geolocator.openAppSettings(),
            child: Text(
              'Open Settings',
              style: textTheme.bodyExtraSmallSemi.copyWith(
                color: colors.primary60,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionArea(
    BuildContext context,
    CrawlClaimState state,
    ColorScheme colors,
    TextTheme textTheme,
  ) {
    return switch (state) {
      AcquiringGps() => _buildClaimButton(
          enabled: false,
          label: 'Claim Stamp',
          onTap: null,
          colors: colors,
        ),
      ClaimSubmitting() => _buildClaimButton(
          enabled: false,
          label: 'Claim Stamp',
          onTap: null,
          loading: true,
          colors: colors,
        ),
      AlreadyClaimed(:final claimedAt) => _AlreadyClaimedInfo(
          claimedAt: claimedAt,
          colors: colors,
          textTheme: textTheme,
        ),
      LocationTooFar(:final distanceMeters) => _LocationTooFarInfo(
          distanceMeters: distanceMeters,
          colors: colors,
          textTheme: textTheme,
        ),
      GpsDenied() || GpsTimeout() => _buildClaimButton(
          enabled: false,
          label: 'Claim Stamp',
          onTap: null,
          colors: colors,
        ),
      CrawlExpired() => _MessageBanner(
          icon: LucideIcons.clock,
          message: 'This crawl has ended',
          colors: colors,
        ),
      StopInactive() => _MessageBanner(
          icon: LucideIcons.circleX,
          message: 'This stop is no longer active',
          colors: colors,
        ),
      NotRegistered() => _MessageBanner(
          icon: LucideIcons.userX,
          message: 'You are not registered for this crawl',
          colors: colors,
        ),
      ClaimNetworkError(:final failure) => _NetworkErrorArea(
          message: failure.message,
          colors: colors,
          textTheme: textTheme,
          onRetry: _onRetryClaim,
        ),
      ClaimSuccess() || ClaimSuccessWithTierCompletion() => _buildShareCta(colors),
      CrawlClaimInitial() => const SizedBox(),
    };
  }

  Widget _buildShareCta(ColorScheme colors) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(LucideIcons.share2, size: 18),
        label: const Text(
          'Share',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary100,
          side: BorderSide(color: colors.primary100),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _navigateToShare,
      ),
    );
  }

  Widget _buildClaimButton({
    required bool enabled,
    required String label,
    required VoidCallback? onTap,
    bool loading = false,
    required ColorScheme colors,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary100,
          disabledBackgroundColor: colors.primary100.withValues(alpha: 0.5),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  void _onOverlayClose() {
    _overlayTimer?.cancel();
    _overlayTimer = null;
    setState(() => _showStampAnimation = false);
  }

  void _navigateToShare() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ShareCafeStopPage(),
      ),
    );
  }

  void _showTierCompletionSheet(BuildContext context, TierCompletionResult tier) {
    setState(() => _showStampAnimation = false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TierCompletionModal(
        tier: tier,
        shareCardKey: _shareCardKey,
        onContinue: () {
          Navigator.pop(context);
          context.pop();
        },
      ),
    );
  }
}

class _StopChip extends StatelessWidget {
  final int stopOrder;
  final String tier;

  const _StopChip({required this.stopOrder, required this.tier});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.gray),
      ),
      child: Text(
        'Stop $stopOrder · ${tier[0].toUpperCase()}${tier.substring(1)} Tier',
        style: TextStyle(
          color: colors.gray,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _AlreadyClaimedInfo extends StatelessWidget {
  final DateTime claimedAt;
  final ColorScheme colors;
  final TextTheme textTheme;

  const _AlreadyClaimedInfo({
    required this.claimedAt,
    required this.colors,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr =
        '${months[claimedAt.month]} ${claimedAt.day}, ${claimedAt.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary20.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.stamp, size: 20, color: colors.primary60),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Already Claimed',
                  style: textTheme.bodyMediumSemi.copyWith(
                    color: colors.primary100,
                  ),
                ),
                Text(
                  'Claimed on $dateStr',
                  style: textTheme.bodySmall?.copyWith(color: colors.gray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationTooFarInfo extends StatelessWidget {
  final int distanceMeters;
  final ColorScheme colors;
  final TextTheme textTheme;

  const _LocationTooFarInfo({
    required this.distanceMeters,
    required this.colors,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final distanceStr = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
        : '$distanceMeters m';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.mapPinOff, size: 20, color: colors.warning),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Too Far Away',
                  style: textTheme.bodyMediumSemi.copyWith(
                    color: colors.warning,
                  ),
                ),
                Text(
                  'You need to be at the cafe to claim this stamp. '
                  'You are $distanceStr away.',
                  style: textTheme.bodySmall?.copyWith(color: colors.gray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final ColorScheme colors;

  const _MessageBanner({
    required this.icon,
    required this.message,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.error),
          const Gap(12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.error,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkErrorArea extends StatelessWidget {
  final String message;
  final ColorScheme colors;
  final TextTheme textTheme;
  final VoidCallback onRetry;

  const _NetworkErrorArea({
    required this.message,
    required this.colors,
    required this.textTheme,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.wifiOff, size: 20, color: colors.error),
              const Gap(12),
              Expanded(
                child: Text(
                  message,
                  style: textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ),
            ],
          ),
          const Gap(12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
