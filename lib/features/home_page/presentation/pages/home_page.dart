import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_empty_widget.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/core/widgets/error/location_denied_banner.dart';
import 'package:nook/core/widgets/prototype_height.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/home_page/presentation/widgets/home_featured_card.dart';
import 'package:nook/features/home_page/presentation/widgets/home_card_section.dart';
import 'package:nook/features/home_page/presentation/widgets/home_top_bar.dart';
import 'package:nook/injection_container.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:nook/core/extensions/extensions.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _onRefresh(BuildContext context) async {
    final bloc = context.read<HomeBloc>();
    bloc.add(LoadHomeDataEvent());
    await bloc.stream.firstWhere((s) => s is! HomeLoadingState);
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
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state is HomeLoadingState) {
                return _HomeScrollView(
                  onRefresh: () => _onRefresh(context),
                  children: const [_HomeSkeleton()],
                );
              }

              if (state is HomeError) {
                return FullPageErrorWidget(
                  error: AppErrorCopy.fromException(state.error),
                  onRetry: () => _onRetry(context),
                );
              }

              if (state is HomeLoadedState) {
                final hasData = state.featuredCafes.isNotEmpty ||
                    state.newestCafes.isNotEmpty ||
                    state.trendingCafes.isNotEmpty ||
                    state.topRatedCafes.isNotEmpty;

                final locationBanner =
                    state.locationDenied && !state.locationBannerDismissed
                        ? LocationDeniedBanner(
                            visible: true,
                            onDismiss: () => context.read<HomeBloc>().add(
                              HomeDismissLocationBannerEvent(),
                            ),
                          )
                        : null;

                return _HomeScrollView(
                  onRefresh: () => _onRefresh(context),
                  children: [
                    if (locationBanner != null) locationBanner,
                    if (!hasData)
                      const SizedBox(
                        height: 360,
                        child: FullPageEmptyWidget(
                          title: 'No cafes yet',
                          subtitle:
                              'Pull to refresh — new spots appear here soon.',
                        ),
                      )
                    else
                      _HomeContent(state: state),
                    const SizedBox(height: 36),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [const HomeTopBar(), ...children],
        ),
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  final HomeLoadedState state;

  const _HomeContent({required this.state});

  static const _prototypeCafe = CafeSummary(
    id: '',
    name: 'Prototype Cafe Name',
    address: 'Prototype Address',
    rating: 4.9,
    coverImage: null,
    tags: ['Specialty'],
  );

  @override
  Widget build(BuildContext context) {
    final featuredWidth = FeaturedCard.cardWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.featuredCafes.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle('Featured'),
          const SizedBox(height: 12),
          PrototypeHeight(
            prototype: FeaturedCard(
              width: featuredWidth,
              cafe: _prototypeCafe,
            ),
            listView: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: state.featuredCafes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => FeaturedCard(
                width: featuredWidth,
                cafe: state.featuredCafes[i],
              ),
            ),
          ),
        ],
        const SizedBox(height: 36),
        HomeCafeSection(
          title: 'New',
          cafes: state.newestCafes,
          emptySubtitle: 'No new cafes yet',
        ),
        const SizedBox(height: 36),
        HomeCafeSection(
          title: 'Trending',
          cafes: state.trendingCafes,
          emptySubtitle: 'Nothing trending right now',
        ),
        const SizedBox(height: 36),
        HomeCafeSection(
          title: 'Top Rated',
          cafes: state.topRatedCafes,
          emptySubtitle: 'Ratings show up soon',
        ),
      ],
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  static const _skeletonCafe = CafeSummary(
    id: 'skeleton',
    name: 'Cafe Placeholder Name',
    address: 'Street Address Placeholder',
    rating: 4.9,
    coverImage: null,
    tags: ['Specialty'],
  );

  static final _skeletonCafes = List.filled(4, _skeletonCafe);

  @override
  Widget build(BuildContext context) {
    final featuredWidth = FeaturedCard.cardWidth;

    return Skeletonizer(
      enabled: true,
      effect: const PulseEffect(),
      child: IgnorePointer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const _SectionTitle('Featured'),
            const SizedBox(height: 12),
            PrototypeHeight(
              prototype: FeaturedCard(
                width: featuredWidth,
                cafe: _skeletonCafe,
                isSkeleton: true,
              ),
              listView: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: 2,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => FeaturedCard(
                  width: featuredWidth,
                  cafe: _skeletonCafe,
                  isSkeleton: true,
                ),
              ),
            ),
            const SizedBox(height: 36),
            HomeCafeSection(
              title: 'New',
              cafes: _skeletonCafes,
              isSkeleton: true,
            ),
            const SizedBox(height: 36),
            HomeCafeSection(
              title: 'Trending',
              cafes: _skeletonCafes,
              isSkeleton: true,
            ),
            const SizedBox(height: 36),
            HomeCafeSection(
              title: 'Top Rated',
              cafes: _skeletonCafes,
              isSkeleton: true,
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Text(
        text,
        style: context.textTheme.titleLargeSemi.copyWith(
          color: context.colorScheme.black,
        ),
      ),
    );
  }
}
