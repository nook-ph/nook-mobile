import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/analytics/analytics_service.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/core/presentation/widgets/bookmark_icon_button.dart';
import 'package:nook/core/cafe/domain/use_cases/resolve_quick_save_list_usecase.dart';
import 'package:nook/core/preferences/last_saved_list_store.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/presentation/cubit/save_to_list_cubit.dart';
import 'package:nook/injection_container.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nook/features/cafe_details/bloc/cafe_details_bloc.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_event.dart';
import 'package:nook/features/cafe_details/bloc/cafe_details_states.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_bloc.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_state.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_event.dart';
import 'package:go_router/go_router.dart';

import 'package:nook/features/cafe_details/presentation/widgets/cafe_hours_title.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info_header.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_tags_list.dart';
import 'package:nook/features/cafe_details/presentation/widgets/hero_image_slider.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_highlights.dart';
import 'package:nook/features/cafe_details/presentation/pages/reviews_page.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_section.dart';
import 'package:nook/features/cafe_details/presentation/widgets/write_review_sheet.dart';
import 'package:nook/features/lists/presentation/widgets/save_to_list_bottom_sheet.dart';
import 'package:nook/core/presentation/widgets/app_bar_circle_icon_button.dart';

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

  static const double _expandedHeight = 320;
  static const double _collapsedHeight = kToolbarHeight;
  static const double _fadeRange = _expandedHeight - _collapsedHeight - 60;

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
                  final info = AppErrorCopy.fromException(state.error);
                  return Scaffold(
                    backgroundColor: Colors.white,
                    appBar: AppBar(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    body: FullPageErrorWidget(
                      error: info,
                      onRetry: info.type == ErrorType.sessionExpired
                          ? () => context.push('/login')
                          : () => context.read<CafeDetailsBloc>().add(
                              LoadCafeDetailsRequested(cafeId: widget.cafeId),
                            ),
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
                        ),
                      ),
                      builder: (context, offset, heroSlider) {
                        final collapseProgress = (offset / _fadeRange).clamp(
                          0.0,
                          1.0,
                        );
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
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          actions: [
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
                          flexibleSpace: FlexibleSpaceBar(
                            collapseMode: CollapseMode.pin,
                            background: Stack(
                              fit: StackFit.expand,
                              children: [
                                heroSlider!,
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
                        );
                      },
                    ),
                    SliverToBoxAdapter(
                      child: Skeletonizer(
                        enabled: isLoading,
                        effect: const PulseEffect(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 24),

                            CafeInfoHeader(
                              cafe: state is CafeDetailsLoaded
                                  ? state.data
                                  : null,
                            ),

                            const SizedBox(height: 12),

                            CafeTagsList(
                              tags: state is CafeDetailsLoaded
                                  ? state.data.cafeDetails.tags
                                  : const [],
                            ),

                            const SizedBox(height: 24),

                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              child: Text(
                                state is CafeDetailsLoaded
                                    ? state.data.cafeDetails.description
                                    : '',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.black54,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            CafeHoursTile(
                              cafe: state is CafeDetailsLoaded
                                  ? state.data
                                  : null,
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

                            MenuHighlights(
                              width: menuCardWidth,
                              cafe: state is CafeDetailsLoaded
                                  ? state.data
                                  : null,
                            ),

                            const SizedBox(height: 24),

                            CafeInfo(
                              cafe: state is CafeDetailsLoaded
                                  ? state.data
                                  : null,
                            ),

                            const SizedBox(height: 40),

                            ReviewsSection(
                              onSeeMoreTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => MultiBlocProvider(
                                      providers: [
                                        BlocProvider.value(
                                          value: context
                                              .read<CafeDetailsBloc>(),
                                        ),
                                        BlocProvider.value(
                                          value: context.read<ReviewsBloc>(),
                                        ),
                                        BlocProvider.value(
                                          value: context
                                              .read<ReviewSubmitBloc>(),
                                        ),
                                      ],
                                      child: ReviewsPage(
                                        cafeId: widget.cafeId,
                                        cafeRating: state is CafeDetailsLoaded
                                            ? state.data.cafeDetails.rating
                                            : null,
                                        reviewCount: state is CafeDetailsLoaded
                                            ? state.data.cafeDetails.reviewCount
                                            : null,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              onWriteReviewTap: () {
                                final session = Supabase
                                    .instance
                                    .client
                                    .auth
                                    .currentSession;
                                if (session == null) {
                                  context.push('/login');
                                  return;
                                }

                                WriteReviewSheet.show(
                                  context,
                                  cafeId: widget.cafeId,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
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
      final isSaved = await listsBloc.repository.isCafeSavedToAnyUserList(
        cafeId,
      );
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
      context.push('/login');
      return;
    }

    if (_isSaved) {
      await _showSaveToListSheet();
      return;
    }

    _savedStateRequest++;
    setState(() => _isSaving = true);

    try {
      final listsBloc = context.read<ListsBloc>();
      final userId = session.user.id;

      final quickSave = await sl<ResolveQuickSaveListUseCase>()(userId);
      await listsBloc.addCafeToListUseCase(quickSave.listId, widget.cafeId);
      await sl<LastSavedListStore>().setLastSavedListId(
        userId,
        quickSave.listId,
      );

      listsBloc.add(LoadUserLists());

      if (!mounted) return;
      setState(() => _isSaved = true);
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
      _showErrorToast(context, e, goLogin: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showSaveToListSheet() async {
    if (!mounted) return;

    final listsBloc = context.read<ListsBloc>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
