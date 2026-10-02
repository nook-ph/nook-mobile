import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/analytics_service.dart';
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
import 'package:nook/features/cafe_details/bloc/review_submit_bloc.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_state.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_event.dart';
import 'package:go_router/go_router.dart';

import 'package:nook/features/cafe_details/presentation/widgets/cafe_actions_bar.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_your_visit_block.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info_header.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_status_pills.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_guest_sign_in_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_error_view.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_skeleton.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_load_failure.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_tag_groups.dart';
import 'package:nook/features/cafe_details/presentation/widgets/expandable_description.dart';
import 'package:nook/features/cafe_details/presentation/widgets/hero_image_slider.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_highlights.dart';
import 'package:nook/features/cafe_details/presentation/pages/reviews_page.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_preview_section.dart';
import 'package:nook/features/cafe_details/presentation/widgets/write_review_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/features/lists/presentation/widgets/save_to_list_bottom_sheet.dart';
import 'package:nook/core/presentation/widgets/app_bar_circle_icon_button.dart';
import 'package:nook/core/presentation/widgets/review_photo_viewer.dart';

class CafeDetailsPage extends StatefulWidget {
  const CafeDetailsPage({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<CafeDetailsPage> createState() => _CafeDetailsPageState();
}

class _CafeDetailsPageState extends State<CafeDetailsPage> {
  late final ScrollController _scrollController;
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0);
  bool _hasTrackedViewDetails = false;

  /// The photo runs under the sheet by this much; the sheet's top corners
  /// take the same radius.
  static const double _sheetLip = 24;

  final GlobalKey _barKey = GlobalKey();

  static const double _expandedHeight = 296;
  static const double _collapsedHeight = kToolbarHeight;

  /// Scroll distance over which the photo collapses into the bar.
  static const double _collapseRange = _expandedHeight - _collapsedHeight;

  /// The bar turns white only over the last stretch of the collapse, once
  /// the sheet has slid up over the photo.
  static const double _fadeRange = 60;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        _scrollOffset.value = _scrollController.offset;
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasTrackedViewDetails) return;
      _hasTrackedViewDetails = true;
      sl<AnalyticsService>().track(
        widget.cafeId,
        AnalyticsService.viewDetails,
        metadata: {AnalyticsMetadataKeys.screen: 'cafe_details'},
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  /// Height of the pinned bar, so toasts land above it. Read at tap time,
  /// when the bar is always laid out; the estimate is only a fallback.
  double _toastOffset() {
    final box = _barKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.size.height;
    return 72 + MediaQuery.of(context).padding.bottom;
  }

  void _openReviews(BuildContext context, CafeDetailsLoaded state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<CafeDetailsBloc>()),
            BlocProvider.value(value: context.read<ReviewsBloc>()),
            BlocProvider.value(value: context.read<ReviewSubmitBloc>()),
          ],
          child: ReviewsPage(
            cafeId: widget.cafeId,
            cafeRating: state.data.cafeDetails.rating,
            reviewCount: state.data.cafeDetails.reviewCount,
          ),
        ),
      ),
    );
  }

  void _writeReview(BuildContext context) {
    if (Supabase.instance.client.auth.currentSession == null) {
      CafeGuestSignInSheet.show(context, action: CafeGuestAction.writeReview);
      return;
    }
    WriteReviewSheet.show(context, cafeId: widget.cafeId);
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
        CafeAmenitiesSection(groups: groups),
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
      CafeHoursLocationSection(cafe: cafe, groups: groups),
      ReviewsPreviewSection(
        onSeeAllTap: () => _openReviews(context, state),
        onWriteReviewTap: () => _writeReview(context),
        currentUserId: Supabase.instance.client.auth.currentUser?.id,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CafeInfoHeader(cafe: cafe),
        const SizedBox(height: 16),
        CafeStatusPills(cafe: cafe, toastOffset: _toastOffset),
        // Your own history with the cafe, right under the actions that
        // create it. Renders nothing unless it's a Been.
        CafeYourVisitBlock(
          cafeId: widget.cafeId,
          cafeName: details.name,
          cafeImageUrl: details.featuredImageUrl,
        ),
        for (final section in sections) ...[
          const CafeSectionDivider(),
          section,
        ],
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
        BlocProvider(
          // Not lazy: the first reader is the reviews section, which only
          // builds once the cafe has loaded. The reviews should already be
          // on their way by then, not start after it.
          lazy: false,
          create: (_) =>
              sl<ReviewsBloc>()
                ..add(LoadReviewsRequested(cafeId: widget.cafeId)),
        ),
        BlocProvider(create: (_) => sl<ReviewSubmitBloc>()),
      ],
      child: BlocListener<ReviewSubmitBloc, ReviewSubmitState>(
        listener: (context, submitState) {
          if (submitState is! ReviewSubmitSuccess) return;

          context.read<ReviewsBloc>().add(
            LoadReviewsRequested(cafeId: widget.cafeId),
          );

          context.read<CafeDetailsBloc>().add(
            LoadCafeDetailsRequested(cafeId: widget.cafeId),
          );
        },
        child: Theme(
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
            bottomNavigationBar: BlocBuilder<CafeDetailsBloc, CafeDetailsState>(
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
            body: BlocBuilder<CafeDetailsBloc, CafeDetailsState>(
              buildWhen: (previous, current) {
                if (previous is CafeDetailsLoaded &&
                    current is CafeDetailsLoading) {
                  return false;
                }
                return previous != current;
              },
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
                      valueListenable: _scrollOffset,
                      child: RepaintBoundary(
                        child: HeroImageSlider(
                          images: heroImages,
                          isLoading: isLoading,
                          bottomInset: _sheetLip,
                          onImageTap: (index) => showReviewPhotoViewer(
                            context,
                            imageUrls: heroImages,
                            initialIndex: index,
                          ),
                        ),
                      ),
                      builder: (context, offset, heroSlider) {
                        final collapseProgress =
                            ((offset - (_collapseRange - _fadeRange)) /
                                    _fadeRange)
                                .clamp(0.0, 1.0);
                        final titleOpacity = collapseProgress < 0.6
                            ? 0.0
                            : ((collapseProgress - 0.6) / 0.4).clamp(0.0, 1.0);

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
                                thumbnailUrl: state is CafeDetailsLoaded
                                    ? state.data.cafeDetails.featuredImageUrl
                                    : null,
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
        if (cafeName.isEmpty) return;

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
    required this.thumbnailUrl,
  });

  final String cafeId;
  final String cafeName;
  final String? thumbnailUrl;

  @override
  State<_SavedButton> createState() => _SavedButtonState();
}

class _SavedButtonState extends State<_SavedButton> {
  bool _isSaving = false;
  bool _isSaved = false;
  int _savedStateRequest = 0;
  bool _loadErrorToastShown = false;

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
    _loadSavedState();
  }

  @override
  void didUpdateWidget(covariant _SavedButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cafeId != widget.cafeId) {
      _isSaved = false;
      _loadErrorToastShown = false;
      _loadSavedState();
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

  Future<void> _onTap() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      dismissToasts();
      await CafeGuestSignInSheet.show(
        context,
        action: CafeGuestAction.saveToList,
        cafeName: widget.cafeName,
      );
      return;
    }

    if (_isSaved) {
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

      if (!mounted) return;
      showSavedToListToast(
        context,
        widget.cafeName,
        widget.thumbnailUrl,
        listDisplayName: quickSave.displayTitle,
        onChange: () => _showSaveToListSheet(),
      );
    } catch (e, st) {
      debugPrint('[CafeDetailsSave] instant save failed error=$e\n$st');
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
