import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/discovery_events.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/cups/presentation/cubit/cafe_cups_cubit.dart';
import 'package:nook/features/cups/presentation/cup_actions.dart';
import 'package:nook/features/cups/presentation/cup_menu.dart';
import 'package:nook/features/cups/presentation/pages/cafe_cups_page.dart';
import 'package:nook/features/cups/presentation/widgets/cafe_cups_section.dart';
import 'package:nook/features/gallery/domain/entities/cafe_story.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/presentation/cubit/cafe_photos_cubit.dart';
import 'package:nook/core/services/share_service.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/presentation/widgets/bookmark_icon_button.dart';
import 'package:nook/core/cafe/domain/use_cases/resolve_quick_save_list_usecase.dart';
import 'package:nook/core/preferences/last_saved_list_store.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/presentation/cubit/save_to_list_cubit.dart';
import 'package:nook/injection_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nook/features/cafe_details/bloc/cafe_details_bloc.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_event.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_states.dart';
import 'package:nook/features/cafe_details/presentation/guest_action_replay.dart';
import 'package:nook/features/cafe_details/presentation/widgets/similar_cafes_section.dart';
import 'package:go_router/go_router.dart';

import 'package:nook/features/cafe_details/presentation/widgets/cafe_actions_bar.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_claim_link.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_unverified_note.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_your_visit_block.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info_header.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_status_pills.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_error_view.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_skeleton.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_community_photos_section.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_load_failure.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_tag_groups.dart';
import 'package:nook/features/cafe_details/presentation/widgets/expandable_description.dart';
import 'package:nook/features/cafe_details/presentation/widgets/hero_image_slider.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_highlights.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/features/lists/presentation/widgets/save_to_list_bottom_sheet.dart';
import 'package:nook/core/presentation/widgets/app_bar_circle_icon_button.dart';
import 'package:nook/core/presentation/widgets/review_photo_viewer.dart';

/// The scroll offset that puts a section whose top is at [reveal] just
/// under a pinned bar [bar] tall, with a little air, within [min]..[max].
double scrollOffsetUnderBar({
  required double reveal,
  required double bar,
  required double min,
  required double max,
}) => (reveal - bar + 8).clamp(min, max);

class CafeDetailsPage extends StatefulWidget {
  const CafeDetailsPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeDetailsPage> createState() => _CafeDetailsPageState();
}

class _CafeDetailsPageState extends State<CafeDetailsPage> {
  late final ScrollController _scrollController;

  /// How far the bar has faded to white, 0 to 1. Only this is kept, not the
  /// raw offset: it sits at 0 or 1 for most of a scroll, and a notifier
  /// whose value has not changed rebuilds nothing.
  final ValueNotifier<double> _collapseProgress = ValueNotifier(0);
  bool _hasTrackedViewDetails = false;

  /// The photo runs under the sheet by this much; the sheet's top corners
  /// take the same radius.
  static const double _sheetLip = 24;

  final GlobalKey _barKey = GlobalKey();

  /// The Cups section, which the header's rating scrolls to.
  final GlobalKey _cupsKey = GlobalKey();

  static const double _expandedHeight = 296;
  static const double _collapsedHeight = kToolbarHeight;

  /// Scroll distance over which the photo collapses into the bar.
  static const double _collapseRange = _expandedHeight - _collapsedHeight;

  /// The bar turns white only over the last stretch of the collapse, once
  /// the sheet has slid up over the photo.
  static const double _fadeRange = 60;

  /// A guest tapped Add your cup, signed in and was brought back here:
  /// open the composer once the cafe has loaded.
  bool _pendingAddCup = false;

  /// The page's cups and the stories tray's photos, made here so a posted
  /// cup refreshes both.
  late final CafeCupsCubit _cups = CafeCupsCubit(
    repository: sl<ICupsRepository>(),
    cafeId: widget.cafeId,
  )..load();
  late final CafePhotosCubit _photos = sl<CafePhotosCubit>(
    param1: widget.cafeId,
  )..load();

  @override
  void initState() {
    super.initState();
    _pendingAddCup =
        Supabase.instance.client.auth.currentSession != null &&
        GuestActionReplay.take(CafeGuestAction.writeReview, widget.cafeId);
    _scrollController = ScrollController()
      ..addListener(() {
        _collapseProgress.value =
            ((_scrollController.offset - (_collapseRange - _fadeRange)) /
                    _fadeRange)
                .clamp(0.0, 1.0);
      });
  }

  /// Logged once per visit, and only when the cafe loaded: a bad id or a
  /// failed fetch is not a details view.
  void _trackViewDetails() {
    if (_hasTrackedViewDetails) return;
    _hasTrackedViewDetails = true;
    sl<AnalyticsService>().track(
      widget.cafeId,
      AnalyticsService.viewDetails,
      metadata: {AnalyticsMetadataKeys.screen: 'cafe_details'},
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _collapseProgress.dispose();
    _cups.close();
    _photos.close();
    super.dispose();
  }

  /// Height of the pinned bar, so toasts land above it. Read at tap time,
  /// when the bar is always laid out; the estimate is only a fallback.
  double _toastOffset() {
    final box = _barKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.size.height;
    return 72 + MediaQuery.of(context).padding.bottom;
  }

  /// The header's rating was tapped: bring the Cups section up under the
  /// pinned bar, where its numbers and kinds explain the rating.
  void _scrollToCups() {
    final box = _cupsKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !_scrollController.hasClients) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final bar = _collapsedHeight + MediaQuery.paddingOf(context).top;
    final position = _scrollController.position;
    final target = scrollOffsetUnderBar(
      reveal: viewport.getOffsetToReveal(box, 0).offset,
      bar: bar,
      min: position.minScrollExtent,
      max: position.maxScrollExtent,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _scrollController.jumpTo(target);
    } else {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  PickedCafe _pickedCafe(CafeDetailsLoaded state) {
    final details = state.data.cafeDetails;
    final area = [
      details.neighborhood,
      details.city,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    return PickedCafe(
      id: widget.cafeId,
      name: details.name,
      area: area.isEmpty ? null : area,
      imageUrl: details.featuredImageUrl,
    );
  }

  List<CupMenuOption> _menu(CafeDetailsLoaded state) =>
      cupMenuFrom(state.data.allMenuItems);

  /// A cup was posted, edited or deleted: the section, the tray and the
  /// header (which shows the cafe's rating) catch up; Been too, when
  /// posting marked it.
  void _afterCup(BuildContext context, {bool markedBeen = false}) {
    _cups.load(refresh: true);
    _photos.load(refresh: true);
    context.read<CafeDetailsBloc>().add(
      LoadCafeDetailsRequested(cafeId: widget.cafeId),
    );
    if (markedBeen) {
      context.read<CafeStatusCubit?>()?.loadFor([widget.cafeId]);
    }
  }

  Future<void> _addCup(
    BuildContext context,
    CafeDetailsLoaded state, {
    required String source,
    CupCard? editing,
  }) async {
    final outcome = await startCup(
      context,
      cafe: _pickedCafe(state),
      source: source,
      editing: editing,
      menu: _menu(state),
      myCups: _myCups,
      toastOffset: _toastOffset(),
    );
    if (outcome == null || !context.mounted) return;
    _afterCup(context, markedBeen: outcome.markedBeen);
  }

  /// Your cups here, once the section has them; else the composer asks.
  List<CupCard>? get _myCups =>
      _cups.state.isLoaded ? _cups.state.myCups : null;

  void _openCups(
    BuildContext context,
    CafeDetailsLoaded state, {
    CafeCupsTab tab = CafeCupsTab.posts,
    CafePhotosState? photos,
  }) {
    CafeCupsPage.open(
      context,
      cafe: _pickedCafe(state),
      initialTab: tab,
      menu: _menu(state),
      photosSeed: photos,
      onChanged: () => _afterCup(context),
    );
  }

  /// A legacy review photo's words for the story viewer, from the cups
  /// this page has loaded.
  StoryReview? _reviewWords(String reviewId) {
    for (final card in _cups.state.cards) {
      if (card.reviewId == reviewId) {
        return StoryReview(rating: card.rating, text: card.note ?? '');
      }
    }
    return null;
  }

  /// The sheet's content for a loaded cafe. Sections with nothing in them
  /// are left out, divider included, instead of printing "No ... listed".
  Widget _buildSections(
    BuildContext context,
    CafeDetailsLoaded state,
    double menuCardWidth,
  ) {
    final cafe = state.data;
    final details = cafe.cafeDetails;
    final groups = CafeTagGroups.from(details.tags);
    final description = details.description.trim();

    final sections = <Widget>[
      if (CafeAmenitiesSection.hasContent(groups))
        CafeAmenitiesSection(
          groups: groups,
          cafeId: widget.cafeId,
          cafeName: details.name,
        ),
      if (description.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CafeDetailsTokens.gutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CafeSectionTitle('About'),
              const SizedBox(height: 8),
              ExpandableDescription(
                text: description,
                collapsedMaxLines: 3,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: CafeDetailsTokens.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      if (cafe.menuHighlights.isNotEmpty)
        MenuHighlights(width: menuCardWidth, cafe: cafe),
      // Cups above Hours: what people had and thought is the proof for
      // deciding, so it sits higher than the logistics (UX review 1.2).
      CafeCupsSection(
        key: _cupsKey,
        onSeeAll: () => _openCups(context, state),
        onAdd: () => _addCup(context, state, source: CupSource.cafeSection),
        onOpenPhoto: (card, index) => openCupPhotos(
          context,
          card: card,
          index: index,
          cafeId: widget.cafeId,
          cafeName: details.name,
        ),
        onHelpful: (card) => toggleCupHelpful(
          context,
          cubit: _cups,
          card: card,
          toastOffset: _toastOffset(),
        ),
        onMore: (card) => showCupOptions(
          context,
          card: card,
          cafeId: widget.cafeId,
          cafeName: details.name,
          onEdit: () => _addCup(
            context,
            state,
            source: CupSource.cafeSection,
            editing: card,
          ),
          onChanged: () => _afterCup(context),
          toastOffset: _toastOffset(),
        ),
      ),
      CafeHoursLocationSection(cafe: cafe, groups: groups),
    ];

    final cups = context.watch<CafeCupsCubit>().state;
    final cupCount = cups.isLoaded ? cups.stats.cupCount : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CafeInfoHeader(cafe: cafe, onRatingTap: _scrollToCups),
        // Imported from public sources and unchecked: say so under the name.
        CafeUnverifiedNote(cafeId: widget.cafeId, isClaimed: details.isClaimed),
        const SizedBox(height: 16),
        CafeStatusPills(cafe: cafe, toastOffset: _toastOffset),
        // Your own history with the cafe, right under the actions that
        // create it. Renders nothing unless it's a Been.
        CafeYourVisitBlock(
          cafeId: widget.cafeId,
          cafeName: details.name,
          cafeImageUrl: details.featuredImageUrl,
          onShareCup: (note) =>
              startCup(
                context,
                cafe: _pickedCafe(state),
                source: CupSource.visitBlock,
                note: note,
                menu: _menu(state),
                myCups: _myCups,
                toastOffset: _toastOffset(),
              ).then((outcome) {
                if (outcome != null && context.mounted) {
                  _afterCup(context, markedBeen: outcome.markedBeen);
                }
              }),
        ),
        // Latest cups: the stories tray, the page's highlight. Brings its
        // own divider, and is left out when there is nothing to show.
        CafeCommunityPhotosSection(
          cafeId: widget.cafeId,
          cafeName: details.name,
          cafeArea: [
            details.neighborhood,
            details.city,
          ].where((part) => part.trim().isNotEmpty).join(', '),
          cafeImageUrl: details.featuredImageUrl,
          cubit: _photos,
          cupCount: cupCount,
          reviewOf: _reviewWords,
          onAdd: () => _addCup(context, state, source: CupSource.storiesTray),
          onSeeAll: (photos) => _openCups(
            context,
            state,
            tab: CafeCupsTab.photos,
            photos: photos,
          ),
        ),
        for (final section in sections) ...[
          const CafeSectionDivider(),
          section,
        ],
        SimilarCafesSection(cafeId: widget.cafeId),
        CafeClaimLink(cafeId: widget.cafeId, isClaimed: details.isClaimed),
        // Clearance above the pinned bar.
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final menuCardWidth = ((screenWidth - 44) / 2) - 6;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              sl<CafeDetailsBloc>()
                ..add(LoadCafeDetailsRequested(cafeId: widget.cafeId)),
        ),
        // Made by the page (see _cups, _photos); started at once, so they
        // are on their way while the cafe loads.
        BlocProvider.value(value: _cups),
        BlocProvider.value(value: _photos),
      ],
      child: BlocListener<CafeDetailsBloc, CafeDetailsState>(
        listenWhen: (_, current) =>
            _pendingAddCup && current is CafeDetailsLoaded,
        listener: (context, detailsState) {
          _pendingAddCup = false;
          if (detailsState is! CafeDetailsLoaded) return;
          _addCup(context, detailsState, source: CupSource.guestReturn);
        },
        child: Builder(
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(
              appBarTheme: const AppBarTheme(
                surfaceTintColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
              ),
            ),
            child: Scaffold(
              backgroundColor: Colors.white,
              extendBodyBehindAppBar: true,
              bottomNavigationBar:
                  BlocBuilder<CafeDetailsBloc, CafeDetailsState>(
                    builder: (context, state) {
                      if (state is CafeDetailsInitial ||
                          state is CafeDetailsLoading) {
                        return const CafeActionsBarSkeleton();
                      }
                      if (state is! CafeDetailsLoaded) {
                        return const SizedBox.shrink();
                      }
                      return KeyedSubtree(
                        key: _barKey,
                        child: CafeActionsBar(cafe: state.data),
                      );
                    },
                  ),
              body: BlocConsumer<CafeDetailsBloc, CafeDetailsState>(
                listenWhen: (_, current) => current is CafeDetailsLoaded,
                listener: (_, _) => _trackViewDetails(),
                buildWhen: (previous, current) {
                  if (previous is CafeDetailsLoaded &&
                      current is CafeDetailsLoading) {
                    return false;
                  }
                  return previous != current;
                },
                builder: (context, state) {
                  final isLoading =
                      state is CafeDetailsInitial ||
                      state is CafeDetailsLoading;

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
                    final failure = CafeLoadFailure.from(state.error);
                    void back() => Navigator.maybePop(context);
                    if (failure.isNotFound) {
                      return CafeDetailsErrorView.notFound(
                        onBack: back,
                        onSearch: () => context.push('/search'),
                        onHome: () => context.go('/'),
                      );
                    }
                    return CafeDetailsErrorView.forError(
                      info: failure.info,
                      onBack: back,
                      onSignIn: () => context.push('/login'),
                      onRetry: () => context.read<CafeDetailsBloc>().add(
                        LoadCafeDetailsRequested(cafeId: widget.cafeId),
                      ),
                    );
                  }

                  final title = state is CafeDetailsLoaded
                      ? state.data.cafeDetails.name
                      : '';

                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      ValueListenableBuilder<double>(
                        valueListenable: _collapseProgress,
                        child: RepaintBoundary(
                          child: HeroImageSlider(
                            images: heroImages,
                            isLoading: isLoading,
                            bottomInset: _sheetLip,
                            placeholderSeed: state is CafeDetailsLoaded
                                ? state.data.cafeDetails.name
                                : null,
                            onClaimTap:
                                state is CafeDetailsLoaded &&
                                    state.data.cafeDetails.isClaimed == false
                                ? () => CafeClaimLink.open(
                                    context,
                                    cafeId: widget.cafeId,
                                    source: 'no_photos_hero',
                                  )
                                : null,
                            onImageTap: (index) => showReviewPhotoViewer(
                              context,
                              imageUrls: heroImages,
                              initialIndex: index,
                            ),
                          ),
                        ),
                        builder: (context, collapseProgress, heroSlider) {
                          final titleOpacity = collapseProgress < 0.6
                              ? 0.0
                              : ((collapseProgress - 0.6) / 0.4).clamp(
                                  0.0,
                                  1.0,
                                );

                          return SliverAppBar(
                            expandedHeight: _expandedHeight,
                            collapsedHeight: _collapsedHeight,
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
                                child: AppBarCircleIconButton(
                                  icon: Icons.arrow_back,
                                  iconSize: 18,
                                  onTap: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                            title: Opacity(
                              opacity: titleOpacity,
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            actions: [
                              Center(
                                child: _ShareButton(
                                  cafeId: widget.cafeId,
                                  cafeName: state is CafeDetailsLoaded
                                      ? state.data.cafeDetails.name
                                      : '',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Center(
                                child: _SavedButton(
                                  cafeId: widget.cafeId,
                                  cafeName: state is CafeDetailsLoaded
                                      ? state.data.cafeDetails.name
                                      : '',
                                  toastOffset: _toastOffset,
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
                            // The photo drifts up at a quarter of the scroll
                            // speed (parallax) while the bar's bottom edge, and
                            // the sheet lip drawn on it, move at full speed, so
                            // the sheet slides up over the photo.
                            flexibleSpace: Stack(
                              fit: StackFit.expand,
                              children: [
                                FlexibleSpaceBar(
                                  collapseMode: CollapseMode.parallax,
                                  background: heroSlider,
                                ),
                                IgnorePointer(
                                  child: ColoredBox(
                                    color: Colors.white.withValues(
                                      alpha: collapseProgress,
                                    ),
                                  ),
                                ),
                                // The sheet's rounded top edge, pinned to the
                                // bar's bottom so it travels with the sheet.
                                const Align(
                                  alignment: Alignment.bottomCenter,
                                  child: IgnorePointer(
                                    child: SizedBox(
                                      height: _sheetLip,
                                      width: double.infinity,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(_sheetLip),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      SliverToBoxAdapter(
                        child: state is CafeDetailsLoaded
                            ? _buildSections(context, state, menuCardWidth)
                            : const CafeDetailsSkeleton(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.cafeId, required this.cafeName});

  final String cafeId;
  final String cafeName;

  @override
  Widget build(BuildContext context) {
    return AppBarCircleIconButton(
      icon: PhosphorIcons.shareNetwork(),
      iconSize: 18,
      onTap: () {
        // Details are still loading — a share with no name reads broken, and
        // the load takes well under a second.
        if (cafeName.isEmpty) {
          logAppEvent(
            CafeDetailsEvents.shareNotReady,
            properties: {'cafe_id': cafeId},
          );
          return;
        }

        // iPadOS anchors its share popover to this rect; everywhere else it
        // is ignored.
        final box = context.findRenderObject() as RenderBox?;
        final origin = (box != null && box.hasSize)
            ? box.localToGlobal(Offset.zero) & box.size
            : null;

        unawaited(
          sl<AnalyticsService>().track(
            cafeId,
            'share_cafe',
            metadata: {AnalyticsMetadataKeys.screen: 'cafe_details'},
          ),
        );
        unawaited(
          sl<ShareService>().shareCafe(
            id: cafeId,
            name: cafeName,
            sharePositionOrigin: origin,
          ),
        );
      },
    );
  }
}

class _SavedButton extends StatefulWidget {
  const _SavedButton({
    required this.cafeId,
    required this.cafeName,
    required this.toastOffset,
  });

  final String cafeId;
  final String cafeName;

  /// Height of the pinned action bar, so the saved toast lands above it.
  final double Function() toastOffset;

  @override
  State<_SavedButton> createState() => _SavedButtonState();
}

class _SavedButtonState extends State<_SavedButton> {
  bool _isSaving = false;
  bool _isSaved = false;
  int _savedStateRequest = 0;
  bool _loadErrorToastShown = false;

  /// The saved-state read in flight. A tap waits for it: quick-saving on a
  /// guess would re-add a cafe that is already saved.
  Future<void>? _savedStateLoad;

  void _showErrorToast(
    BuildContext context,
    Object e, {
    required bool goLogin,
  }) {
    final info = AppErrorCopy.fromException(e);
    if (goLogin && info.type == ErrorType.sessionExpired) {
      showPrimaryToast(context, info.title);
      context.push('/login');
      return;
    }
    showPrimaryToast(context, '${info.title} · ${info.subtitle}');
  }

  @override
  void initState() {
    super.initState();
    _savedStateLoad = _loadSavedState();
    _finishGuestSave();
  }

  /// A guest tapped Save, signed in and was brought back here: save it now,
  /// unless it is already in one of their lists.
  void _finishGuestSave() {
    if (Supabase.instance.client.auth.currentSession == null) return;
    if (!GuestActionReplay.take(CafeGuestAction.saveToList, widget.cafeId)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _savedStateLoad;
      if (!mounted || _isSaved) return;
      await _onTap();
    });
  }

  @override
  void didUpdateWidget(covariant _SavedButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cafeId != widget.cafeId) {
      _isSaved = false;
      _loadErrorToastShown = false;
      _savedStateLoad = _loadSavedState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BookmarkIconButton(
      isSaved: _isSaved,
      isEnabled: !_isSaving,
      onTap: _onTap,
    );
  }

  Future<void> _loadSavedState() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final requestId = ++_savedStateRequest;
    final listsBloc = context.read<ListsBloc>();
    final cafeId = widget.cafeId;

    try {
      // The user's lists are usually in memory already, which leaves one
      // membership query (or none, without a custom list) instead of
      // fetching the lists again first.
      final known = listsBloc.userLists;
      final bool isSaved;
      if (known.isEmpty) {
        isSaved = await listsBloc.repository.isCafeSavedToAnyUserList(cafeId);
      } else {
        // Custom lists only, as in isCafeSavedToAnyUserList.
        final custom = [
          for (final list in known)
            if (!list.isSystem) list.id,
        ];
        isSaved =
            custom.isNotEmpty &&
            (await listsBloc.repository.getCafeListMemberships(
              cafeId,
              custom,
            )).isNotEmpty;
      }
      if (!mounted ||
          widget.cafeId != cafeId ||
          requestId != _savedStateRequest)
        return;
      setState(() => _isSaved = isSaved);
    } catch (e, st) {
      debugPrint(
        '[CafeDetailsSave] _loadSavedState failed cafeId=$cafeId error=$e\n$st',
      );
      if (!mounted || _loadErrorToastShown) return;
      _loadErrorToastShown = true;
      _showErrorToast(context, e, goLogin: true);
    }
  }

  void _logSave(String result) => logAppEvent(
    CafeDetailsEvents.saveTapped,
    properties: {'cafe_id': widget.cafeId, 'result': result},
  );

  Future<void> _onTap() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _logSave('guest');
      dismissToasts();
      await CafeGuestSignInSheet.show(
        context,
        action: CafeGuestAction.saveToList,
        cafeName: widget.cafeName,
        cafeId: widget.cafeId,
      );
      return;
    }

    if (_isSaving) {
      _logSave('busy');
      return;
    }
    await _savedStateLoad;
    if (!mounted) return;

    if (_isSaved) {
      _logSave('opened_lists');
      await _showSaveToListSheet();
      return;
    }

    // The bookmark fills at once and empties again if the save fails.
    _savedStateRequest++;
    setState(() {
      _isSaving = true;
      _isSaved = true;
    });

    try {
      final listsBloc = context.read<ListsBloc>();
      final userId = session.user.id;

      final quickSave = await sl<ResolveQuickSaveListUseCase>()(
        userId,
        knownLists: listsBloc.userLists,
      );
      await listsBloc.addCafeToListUseCase(quickSave.listId, widget.cafeId);
      await sl<LastSavedListStore>().setLastSavedListId(
        userId,
        quickSave.listId,
      );

      listsBloc.add(LoadUserLists());

      _logSave('saved');
      if (!mounted) return;
      showSavedToListToast(
        context,
        listDisplayName: quickSave.displayTitle,
        onChange: () => _showSaveToListSheet(),
        bottomOffset: widget.toastOffset(),
      );
    } catch (e, st) {
      debugPrint('[CafeDetailsSave] instant save failed error=$e\n$st');
      _logSave('failed');
      if (!mounted) return;
      setState(() => _isSaved = false);
      _showErrorToast(context, e, goLogin: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showSaveToListSheet() async {
    if (!mounted) return;

    final listsBloc = context.read<ListsBloc>();

    await ListsSheet.show<void>(
      context,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: listsBloc),
          BlocProvider(create: (_) => sl<SaveToListCubit>()),
        ],
        child: SaveToListBottomSheet(cafeId: widget.cafeId),
      ),
    );

    if (mounted) {
      _loadSavedState();
      context.read<ListsBloc>().add(LoadUserLists());
    }
  }
}
