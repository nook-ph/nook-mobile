import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/injection_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:nook/features/cafe_details/bloc/cafe_details_bloc.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_event.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_states.dart';
import 'package:go_router/go_router.dart';

import 'package:nook/features/cafe_details/presentation/widgets/cafe_hours_title.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info_header.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_tags_list.dart';
import 'package:nook/features/cafe_details/presentation/widgets/hero_image_slider.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_highlights.dart';

class CafeDetailsPage extends StatefulWidget {
  const CafeDetailsPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeDetailsPage> createState() => _CafeDetailsPageState();
}

class _CafeDetailsPageState extends State<CafeDetailsPage> {
  late final ScrollController _scrollController;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset;
        });
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double expandedHeight = 320;
    const double collapsedHeight = kToolbarHeight;
    final double fadeRange = expandedHeight - collapsedHeight - 60;
    final double collapseProgress = (_scrollOffset / fadeRange).clamp(0.0, 1.0);

    final screenWidth = MediaQuery.of(context).size.width;
    final menuCardWidth = ((screenWidth - 44) / 2) - 6;

    return BlocProvider(
      create: (_) =>
          sl<CafeDetailsBloc>()
            ..add(LoadCafeDetailsRequested(cafeId: widget.cafeId)),
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        body: BlocBuilder<CafeDetailsBloc, CafeDetailsState>(
          builder: (context, state) {
            final isLoading =
                state is CafeDetailsInitial || state is CafeDetailsLoading;

            final heroImages = state is CafeDetailsLoaded
                ? [
                    if ((state.data.cafeDetails.featuredImageUrl ?? '')
                        .isNotEmpty)
                      state.data.cafeDetails.featuredImageUrl!,
                    ...state.data.cafeDetails.photos.where(
                      (url) =>
                          url.isNotEmpty &&
                          url != state.data.cafeDetails.featuredImageUrl,
                    ),
                  ]
                : const <String>[];

            if (state is CafeDetailsError) {
              return Center(
                child: Text(
                  'Error loading cafes: ${state.message}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final titleOpacity = collapseProgress < 0.6
                ? 0.0
                : ((collapseProgress - 0.6) / 0.4).clamp(0.0, 1.0);

            final title = state is CafeDetailsLoaded
                ? state.data.cafeDetails.name
                : '';

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                Theme(
                  data: Theme.of(context).copyWith(
                    appBarTheme: const AppBarTheme(
                      surfaceTintColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      elevation: 0,
                    ),
                  ),
                  child: SliverAppBar(
                    expandedHeight: expandedHeight,
                    collapsedHeight: collapsedHeight,
                    pinned: true,
                    elevation: 0,
                    backgroundColor: Colors.white.withValues(
                      alpha: collapseProgress,
                    ),
                    automaticallyImplyLeading: false,
                    leadingWidth: 70,
                    leading: Padding(
                      padding: const EdgeInsets.only(left: 22.0),
                      child: Center(
                        child: _AppBarIconButton(
                          icon: Icons.arrow_back,
                          iconSize: 18,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    title: AnimatedOpacity(
                      duration: Duration.zero,
                      opacity: titleOpacity,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    actions: [
                      Center(
                        child: _AppBarIconButton(
                          icon: PhosphorIcons.share(),
                          iconSize: 16,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Center(
                        child: _AppBarIconButton(
                          icon: PhosphorIcons.heart(),
                          iconSize: 16,
                          onTap: () {
                            context.push('/login');
                          },
                        ),
                      ),
                      const SizedBox(width: 22),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(0.5),
                      child: Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: Colors.black.withValues(
                          alpha: collapseProgress * 0.15,
                        ),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          HeroImageSlider(
                            images: heroImages,
                            isLoading: isLoading,
                          ),
                          IgnorePointer(
                            child: Container(
                              color: Colors.white.withValues(
                                alpha: collapseProgress,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Skeletonizer(
                    enabled: isLoading,
                    effect: const PulseEffect(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        /// Header
                        CafeInfoHeader(
                          cafe: state is CafeDetailsLoaded ? state.data : null,
                        ),

                        const SizedBox(height: 24),

                        /// Tags
                        CafeTagsList(
                          tags: state is CafeDetailsLoaded
                              ? state.data.cafeDetails.tags
                              : const [],
                        ),

                        const SizedBox(height: 24),

                        /// Description
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 22),
                          child: Text(
                            state is CafeDetailsLoaded
                                ? state.data.cafeDetails.description
                                : '',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        /// Hours
                        CafeHoursTile(
                          cafe: state is CafeDetailsLoaded ? state.data : null,
                        ),

                        const Padding(
                          padding: EdgeInsets.only(left: 66, right: 22),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFE0E0E0),
                          ),
                        ),

                        const SizedBox(height: 24),

                        /// Menu
                        MenuHighlights(
                          width: menuCardWidth,
                          cafe: state is CafeDetailsLoaded ? state.data : null,
                        ),

                        const SizedBox(height: 24),

                        /// Info
                        CafeInfo(
                          cafe: state is CafeDetailsLoaded ? state.data : null,
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({
    required this.icon,
    required this.iconSize,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Icon(icon, color: Colors.black, size: iconSize),
      ),
    );
  }
}
