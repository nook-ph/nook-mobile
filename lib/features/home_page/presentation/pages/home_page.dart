import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/cache/custom_cache_manager.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/utils/responsive_card_sizes.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/core/widgets/error/location_denied_banner.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/home_page/presentation/widgets/home_card_section.dart';
import 'package:nook/features/home_page/presentation/widgets/home_featured_card.dart';
import 'package:nook/features/home_page/presentation/widgets/home_state_view.dart';
import 'package:nook/features/home_page/presentation/widgets/home_top_bar.dart';
import 'package:nook/injection_container.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _onRefresh(BuildContext context) async {
    final bloc = context.read<HomeBloc>();
    // Wait for the state the refresh ends in. A refresh over a loaded feed
    // emits no loading state, so the first emission is already the outcome.
    // Leaving the screen closes the bloc mid-refresh; the stream then ends
    // with no match, which is not an error.
    final done = bloc.stream.firstWhere(
      (s) => s is! HomeLoadingState,
      orElse: () => bloc.state,
    );
    bloc.add(LoadHomeDataEvent(refresh: true));
    await done;
  }

  void _onRetry(BuildContext context) {
    final state = context.read<HomeBloc>().state;
    if (state is HomeError) {
      final info = AppErrorCopy.fromException(state.error);
      if (info.type == ErrorType.sessionExpired) {
        context.push('/login');
        return;
      }
    }
    context.read<HomeBloc>().add(LoadHomeDataEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<HomeBloc>()..add(LoadHomeDataEvent()),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: RetryOnResume(
            child: BlocListener<HomeBloc, HomeState>(
              // Fires for a first load and for a refresh, but not for a banner
              // dismissal, which re-emits the same lists.
              listenWhen: (prev, curr) =>
                  curr is HomeLoadedState &&
                  (prev is! HomeLoadedState ||
                      curr.refreshError != null ||
                      !identical(prev.featuredCafes, curr.featuredCafes)),
              listener: (context, state) {
                if (state is! HomeLoadedState) return;

                final refreshError = state.refreshError;
                if (refreshError != null) {
                  showPrimaryToast(
                    context,
                    HomeStateView.errorCopy(refreshError).title,
                  );
                  return;
                }

                // One batched get_cafe_statuses for everything on the feed, so
                // the Been / Want to Try badges can render per card without a
                // request per card (spec §3.2).
                // A load that emits twice only asks about the cafes the second
                // emission added.
                final ids = state.newCafeIds ?? state.cafeIds;
                if (ids.isNotEmpty) {
                  context.read<CafeStatusCubit>().loadFor(ids.toList());
                }

                if (state.featuredCafes.isNotEmpty) {
                  final first = state.featuredCafes.first;
                  final url = first.coverImage?.trim().isNotEmpty == true
                      ? first.coverImage!.trim()
                      : 'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

                  precacheImage(
                    CachedNetworkImageProvider(
                      url,
                      cacheManager: CustomCacheManager.instance,
                    ),
                    context,
                  );
                }
              },
              // The top bar sits outside the feed's scroll view: search stays
              // reachable in every state, and the refresh spinner appears
              // under it.
              child: BlocListener<AuthBloc, AuthState>(
                // Signing in from a guest sheet keeps this screen alive, so the
                // feed does not reload and its badges have to be asked for.
                listenWhen: (prev, curr) =>
                    curr is AuthAuthenticated && prev is! AuthAuthenticated,
                listener: (context, _) {
                  final home = context.read<HomeBloc>().state;
                  if (home is HomeLoadedState && home.hasCafes) {
                    context.read<CafeStatusCubit>().loadFor(
                      home.cafeIds.toList(),
                    );
                  }
                },
                child: Column(
                  children: [
                    const HomeTopBar(),
                    Expanded(
                      child: BlocBuilder<HomeBloc, HomeState>(
                        builder: (context, state) => _feedArea(context, state),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feedArea(BuildContext context, HomeState state) {
    if (state is HomeLoadingState) {
      return const SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        child: HomeSkeleton(),
      );
    }

    if (state is HomeError) {
      return _HomeScrollView(
        onRefresh: () => _onRefresh(context),
        children: [
          const SizedBox(height: _stateTop),
          HomeStateView.error(
            error: HomeStateView.errorCopy(state.error),
            onRetry: () => _onRetry(context),
          ),
          const SizedBox(height: 24),
        ],
      );
    }

    if (state is HomeLoadedState) {
      final banner = _locationBanner(context, state);

      // The load succeeded and there is nothing to list. A load where every
      // section failed never gets here: the use case throws and the feed
      // shows the error view instead.
      if (!state.hasCafes) {
        return _HomeScrollView(
          onRefresh: () => _onRefresh(context),
          children: [
            ?banner,
            const SizedBox(height: _stateTop),
            const HomeStateView.noCafes(),
            const SizedBox(height: 24),
          ],
        );
      }

      return _HomeScrollView(
        onRefresh: () => _onRefresh(context),
        children: [
          ?banner,
          const SizedBox(height: 12),
          _HomeContent(state: state),
          const SizedBox(height: 36),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  /// Figma: the state block starts 150 below the top bar.
  static const double _stateTop = 150;

  Widget? _locationBanner(BuildContext context, HomeLoadedState state) {
    if (!state.showLocationBanner) return null;
    void dismiss() =>
        context.read<HomeBloc>().add(HomeDismissLocationBannerEvent());

    final banner = state.locationServicesOff
        ? LocationDeniedBanner.servicesOff(visible: true, onDismiss: dismiss)
        : LocationDeniedBanner(visible: true, onDismiss: dismiss);
    // Figma "Banner wrap": 4 above and below.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: banner,
    );
  }
}

class _HomeScrollView extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final List<Widget> children;

  const _HomeScrollView({required this.onRefresh, required this.children});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: context.colorScheme.primary100,
      backgroundColor: context.colorScheme.white,
      // Always scrollable, so pull to refresh works on a short state view.
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final HomeLoadedState state;

  const _HomeContent({required this.state});

  @override
  Widget build(BuildContext context) {
    // Near you leads when the phone has a position: the job is somewhere to
    // go now, and a featured cafe 10 km away answered it worst. A cafe is
    // shown in one shelf's first cards only, so the screen does not repeat
    // itself (docs/ux/find-a-cafe.md, finding 4).
    final seen = <String>{};
    List<CafeSummary> fresh(List<CafeSummary> cafes) {
      final rest = cafes.where((c) => !seen.contains(c.id)).toList();
      final shelf = rest.length >= 3 ? rest : cafes;
      seen.addAll(shelf.take(3).map((c) => c.id));
      return shelf;
    }

    final nearby = fresh(state.nearbyCafes);
    final featured = fresh(state.featuredCafes);
    final newest = fresh(state.newestCafes);
    final trending = fresh(state.trendingCafes);
    final topRated = fresh(state.topRatedCafes);

    // Sections with no cafes are left out, so the gap goes between the ones
    // that remain rather than around blank space.
    final sections = <Widget>[
      if (nearby.isNotEmpty)
        HomeCafeSection(title: 'Near you', cafes: nearby, sort: 'nearby'),
      if (featured.isNotEmpty) _FeaturedSection(cafes: featured),
      if (newest.isNotEmpty)
        HomeCafeSection(title: 'New', cafes: newest, sort: 'newest'),
      if (trending.isNotEmpty)
        HomeCafeSection(title: 'Trending', cafes: trending, sort: 'trending'),
      if (topRated.isNotEmpty)
        HomeCafeSection(title: 'Top Rated', cafes: topRated, sort: 'top_rated'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 28),
          sections[i],
        ],
      ],
    );
  }
}

class _FeaturedSection extends StatelessWidget {
  const _FeaturedSection({required this.cafes});

  final List<CafeSummary> cafes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HomeSectionTitle('Featured'),
        const SizedBox(height: 12),
        FeaturedCarousel(cafes: cafes),
      ],
    );
  }
}

/// The loading feed (Figma 1605:14062): grey blocks in the shape of the real
/// sections, so nothing jumps when the cafes arrive.
class HomeSkeleton extends StatefulWidget {
  const HomeSkeleton({super.key});

  @override
  State<HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<HomeSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.55,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final featuredWidth = ResponsiveCardSizes.featuredCardWidth(context);
    final cardWidth = ResponsiveCardSizes.cafeCardWidth(context);

    Widget row(List<Widget> cards) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: ResponsiveCardSizes.homeGutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: ResponsiveCardSizes.homeCardGap),
            cards[i],
          ],
        ],
      ),
    );

    Widget section(Widget cards) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveCardSizes.homeGutter,
          ),
          child: _Bone(width: 110, height: 18),
        ),
        const SizedBox(height: 12),
        cards,
      ],
    );

    Widget featuredCard() => SizedBox(
      width: featuredWidth,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bone(height: ResponsiveCardSizes.featuredPhotoHeight, radius: 16),
          SizedBox(height: 10),
          _Bone(width: 200, height: 16),
          SizedBox(height: 6),
          _Bone(width: 240, height: 10),
          SizedBox(height: 6),
          _Bone(width: 150, height: 10),
        ],
      ),
    );

    Widget compactCard() => SizedBox(
      width: cardWidth,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Bone(height: ResponsiveCardSizes.cafePhotoHeight, radius: 12),
          SizedBox(height: 8),
          _Bone(width: 130, height: 14),
          SizedBox(height: 6),
          _Bone(width: 170, height: 10),
          SizedBox(height: 6),
          _Bone(width: 90, height: 10),
        ],
      ),
    );

    return Semantics(
      label: 'Loading cafes',
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: _pulse,
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section(row([featuredCard(), featuredCard()])),
                for (var i = 0; i < 3; i++) ...[
                  const SizedBox(height: 28),
                  section(row([compactCard(), compactCard(), compactCard()])),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One grey skeleton block.
class _Bone extends StatelessWidget {
  const _Bone({this.width, required this.height, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Loads the feed again when the app comes back to the foreground while
/// Home shows an error: the usual way back from offline is to fix the
/// connection in Settings and return, and Home sat on "You're offline"
/// until Try again was tapped. (No connectivity package is in the app, so
/// resume is the signal.)
class RetryOnResume extends StatefulWidget {
  const RetryOnResume({super.key, required this.child});

  final Widget child;

  @override
  State<RetryOnResume> createState() => _RetryOnResumeState();
}

class _RetryOnResumeState extends State<RetryOnResume> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  void _onResume() {
    if (!mounted) return;
    final bloc = context.read<HomeBloc>();
    if (bloc.state is HomeError) bloc.add(LoadHomeDataEvent());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
