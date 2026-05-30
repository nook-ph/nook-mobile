import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_empty_widget.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/core/widgets/error/location_denied_banner.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/home_page/presentation/widgets/featured_card.dart';
import 'package:nook/features/home_page/presentation/widgets/home_cafe_section.dart';
import 'package:nook/features/home_page/presentation/widgets/home_top_bar.dart';
import 'package:nook/injection_container.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:nook/core/extensions/extensions.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _refreshHome(BuildContext context) async {
    final bloc = context.read<HomeBloc>();
    bloc.add(LoadHomeDataEvent());
    await bloc.stream.firstWhere((state) => state is! HomeLoadingState);
  }

  void _retryOrSignIn(BuildContext context, VoidCallback reload) {
    final state = context.read<HomeBloc>().state;
    if (state is HomeError) {
      final info = AppErrorCopy.fromException(state.error);
      if (info.type == ErrorType.sessionExpired) {
        context.push('/login');
        return;
      }
    }
    reload();
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
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

  Widget _buildScrollableLayout({
    required BuildContext context,
    required List<Widget> children,
  }) {
    return RefreshIndicator(
      onRefresh: () => _refreshHome(context),
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

  List<Widget> _buildLoadingSkeletonChildren(
    BuildContext context,
    double cardWidth,
    double cardHeight,
  ) {
    final List<CafeSummary> cafes = List.generate(
      4,
      (index) => const CafeSummary(
        id: 'skeleton',
        name: 'Cafe Placeholder Name',
        address: 'Street Address Placeholder',
        rating: 4.9,
        coverImage: null,
        tags: ['Specialty'],
      ),
    );

    return [
      const SizedBox(height: 24),
      Skeletonizer(
        enabled: true,
        effect: const PulseEffect(),
        child: IgnorePointer(
          ignoring: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(context, 'Featured'),
              const SizedBox(height: 12),
              SizedBox(
                height: cardHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: 2,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, index) => FeaturedCard(
                    width: cardWidth,
                    cafe: cafes[index],
                    isSkeleton: true,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              HomeCafeSection(title: 'New', cafes: cafes, isSkeleton: true),
              const SizedBox(height: 24),
              HomeCafeSection(
                title: 'Trending',
                cafes: cafes,
                isSkeleton: true,
              ),
              const SizedBox(height: 24),
              HomeCafeSection(
                title: 'Top Rated',
                cafes: cafes,
                isSkeleton: true,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ];
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
              final double cardWidth = context.screenWidth - 44;
              final textTheme = context.textTheme;
              final double imageHeight = cardWidth * (2 / 3);
              final double titleSize = textTheme.titleMediumSemi.fontSize ?? 0;
              final double titleHeight =
                  titleSize * (textTheme.titleMediumSemi.height ?? 1.0);
              final double bodyMediumSize = textTheme.bodyMedium?.fontSize ?? 0;
              final double bodyMediumHeight =
                  bodyMediumSize * (textTheme.bodyMedium?.height ?? 1.0);
              final double bodySmallSize = textTheme.bodySmallMed.fontSize ?? 0;
              final double bodySmallHeight =
                  bodySmallSize * (textTheme.bodySmallMed.height ?? 1.0);
              final double tagsRowHeight = bodySmallHeight + 4;
              final double cardHeight =
                  imageHeight +
                  10 +
                  titleHeight +
                  4 +
                  bodyMediumHeight +
                  8 +
                  tagsRowHeight +
                  10;

              if (state is HomeLoadingState) {
                return _buildScrollableLayout(
                  context: context,
                  children: _buildLoadingSkeletonChildren(
                    context,
                    cardWidth,
                    cardHeight,
                  ),
                );
              }

              if (state is HomeError) {
                final info = AppErrorCopy.fromException(state.error);
                return FullPageErrorWidget(
                  error: info,
                  onRetry: () => _retryOrSignIn(
                    context,
                    () => context.read<HomeBloc>().add(LoadHomeDataEvent()),
                  ),
                );
              }

              if (state is HomeLoadedState) {
                final showLocBanner =
                    state.locationDenied && !state.locationBannerDismissed;
                final bool hasAnyData =
                    state.featuredCafes.isNotEmpty ||
                    state.newestCafes.isNotEmpty ||
                    state.trendingCafes.isNotEmpty ||
                    state.topRatedCafes.isNotEmpty;

                if (!hasAnyData) {
                  return _buildScrollableLayout(
                    context: context,
                    children: [
                      if (showLocBanner)
                        LocationDeniedBanner(
                          visible: true,
                          onDismiss: () => context.read<HomeBloc>().add(
                            HomeDismissLocationBannerEvent(),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const SizedBox(
                        height: 360,
                        child: FullPageEmptyWidget(
                          title: 'No cafes yet',
                          subtitle:
                              'Pull to refresh — new spots appear here soon.',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }

                return _buildScrollableLayout(
                  context: context,
                  children: [
                    if (showLocBanner)
                      LocationDeniedBanner(
                        visible: true,
                        onDismiss: () => context.read<HomeBloc>().add(
                          HomeDismissLocationBannerEvent(),
                        ),
                      ),
                    if (state.featuredCafes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle(context, 'Featured'),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: cardHeight,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          itemCount: state.featuredCafes.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, index) => FeaturedCard(
                            width: cardWidth,
                            cafe: state.featuredCafes[index],
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                    ] else
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
                    const SizedBox(height: 36),
                  ],
                );
              }

              return _buildScrollableLayout(
                context: context,
                children: const [
                  SizedBox(height: 24),
                  SizedBox(
                    height: 320,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
