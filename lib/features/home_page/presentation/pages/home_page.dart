import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/features/home_page/bloc/home_bloc.dart';
import 'package:nook/features/home_page/bloc/home_event.dart';
import 'package:nook/features/home_page/bloc/home_states.dart';
import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';
import 'package:nook/features/home_page/presentation/widgets/featured_card.dart';
import 'package:nook/features/home_page/presentation/widgets/home_cafe_section.dart';
import 'package:nook/features/home_page/presentation/widgets/home_top_bar.dart';
import 'package:nook/injection_container.dart';
import 'package:skeletonizer/skeletonizer.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _refreshHome(BuildContext context) async {
    final bloc = context.read<HomeBloc>();
    bloc.add(LoadHomeDataEvent());
    await bloc.stream.firstWhere((state) => state is! HomeLoadingState);
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Text(
        text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildMessageState({
    required BuildContext context,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF5E5F60),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                context.read<HomeBloc>().add(LoadHomeDataEvent());
              },
              child: const Text('Retry'),
            ),
          ],
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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [const HomeTopBar(), ...children],
        ),
      ),
    );
  }

  List<Widget> _buildLoadingSkeletonChildren(double cardWidth, double textScale) {
    final List<CafeSummaryEntity> cafes = List.generate(
      4,
      (index) => CafeSummaryEntity(
        id: 'skeleton_$index',
        name: 'Cafe Placeholder Name',
        address: 'Street Address Placeholder',
        rating: 4.9,
        featuredImageUrl: null,
        tags: const ['Specialty'],
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
              _buildSectionTitle('Featured'),
              const SizedBox(height: 12),
              SizedBox(
                height: 312 * textScale,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: 2,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return FeaturedCard(
                      width: cardWidth,
                      cafe: cafes[index],
                      isSkeleton: true,
                    );
                  },
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
              final double screenWidth = MediaQuery.of(context).size.width;
              final double cardWidth = screenWidth - 44;
              final double textScale =
                  MediaQuery.textScalerOf(context).scale(1.0);

              if (state is HomeLoadingState) {
                return _buildScrollableLayout(
                  context: context,
                  children: _buildLoadingSkeletonChildren(cardWidth, textScale),
                );
              }

              if (state is HomeError) {
                return _buildScrollableLayout(
                  context: context,
                  children: [
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 320,
                      child: _buildMessageState(
                        context: context,
                        message:
                            'Unable to load cafes right now. Please try again.',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }

              if (state is HomeLoadedState) {
                final bool hasAnyData =
                    state.featuredCafes.isNotEmpty ||
                    state.newestCafes.isNotEmpty ||
                    state.trendingCafes.isNotEmpty ||
                    state.topRatedCafes.isNotEmpty;

                if (!hasAnyData) {
                  return _buildScrollableLayout(
                    context: context,
                    children: [
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 320,
                        child: _buildMessageState(
                          context: context,
                          message:
                              'No cafes found yet. Pull to refresh or try again.',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }

                return _buildScrollableLayout(
                  context: context,
                  children: [
                    if (state.featuredCafes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle('Featured'),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 312 * textScale,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          itemCount: state.featuredCafes.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return FeaturedCard(
                              width: cardWidth,
                              cafe: state.featuredCafes[index],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else
                      const SizedBox(height: 24),
                    HomeCafeSection(title: 'New', cafes: state.newestCafes),
                    const SizedBox(height: 24),
                    HomeCafeSection(
                      title: 'Trending',
                      cafes: state.trendingCafes,
                    ),
                    const SizedBox(height: 24),
                    HomeCafeSection(
                      title: 'Top Rated',
                      cafes: state.topRatedCafes,
                    ),
                    const SizedBox(height: 16),
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
