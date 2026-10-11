import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/home_page/presentation/widgets/home_state_view.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/cafe/domain/use_cases/get_reviews_written_by_user_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/features/cups/data/legacy_cups.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/domain/i_cups_repository.dart';
import 'package:nook/features/cups/presentation/cubit/profile_cups_cubit.dart';
import 'package:nook/features/cups/presentation/widgets/cup_composer_sheet.dart';
import 'package:nook/features/cups/presentation/widgets/profile_cafe_cups_sheet.dart';
import 'package:nook/features/cups/presentation/widgets/profile_cups_grid.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/data/gallery_photo_picker.dart';
import 'package:nook/features/gallery/domain/i_cafe_picker_source.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/gallery_flows.dart';
import 'package:nook/features/gallery/presentation/pages/gallery_viewer_page.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/features/profile/bloc/avatar_upload_bloc.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:nook/features/profile/presentation/pages/editprofile_page.dart';
import 'package:nook/features/profile/presentation/pages/settings_page.dart';
import 'package:nook/features/profile/presentation/profile_logic.dart';
import 'package:nook/features/profile/presentation/widgets/profile_header.dart';
import 'package:nook/features/profile/presentation/widgets/profile_lists_tab.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ranked_tab.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/core/services/share_service.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/features/public_profile/presentation/cubit/profile_visibility_cubit.dart';
import 'package:nook/features/public_profile/presentation/pages/public_profile_page.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

/// The Profile tab. Creates the profile's blocs and hands over to
/// [ProfileView], which draws every state.
class ProfileRedesignPage extends StatelessWidget {
  const ProfileRedesignPage({super.key, this.isActive = true});

  /// Whether the Profile tab is the one on screen. See [ProfileView.isActive].
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ProfileCubit(
            client: Supabase.instance.client,
            getReviewsWrittenByUser: sl<GetReviewsWrittenByUserUseCase>(),
            updateProfileUseCase: sl(),
            deleteReviewUseCase: sl(),
          )..loadProfile(),
        ),
        BlocProvider(create: (_) => sl<AvatarUploadBloc>()),
        BlocProvider.value(value: sl<ListsBloc>()),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            current is AuthUnauthenticated ||
            current is AuthLoggedOut ||
            current is AuthAccountDeleted ||
            (current is AuthAuthenticated && previous is! AuthAuthenticated),
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // Signed back in on a tab that survived the sign-out (a session
            // that ended without navigating): load the new session's
            // profile instead of staying on "Sign in to see your profile".
            context.read<ProfileCubit>().loadProfile();
            context.read<GalleryCubit>().load();
            context.read<ProfileVisibilityCubit>().load();
            return;
          }
          context.read<ProfileCubit>().clear();
          context.read<ProfileVisibilityCubit>().clear();
        },
        child: ProfileView(isActive: isActive),
      ),
    );
  }
}

/// The profile screen for whatever [ProfileCubit] reports: loading, loaded,
/// failed or signed out. Reads the lists from [ListsBloc] for the counts and
/// the Lists tab.
class ProfileView extends StatefulWidget {
  const ProfileView({
    super.key,
    this.isActive = true,
    this.galleryFlows,
    this.shareProfile,
    this.openPreview,
    this.cupsCubit,
  });

  /// The Cups grid's data. Defaults to one per signed-in user; tests pass
  /// their own.
  final ProfileCupsCubit? cupsCubit;

  /// Shares the profile's web link. Defaults to the system share sheet.
  final ShareProfile? shareProfile;

  /// Opens "View as visitor" for the signed-in user. Defaults to pushing
  /// [PublicProfilePage] in preview mode.
  final void Function(String userId)? openPreview;

  /// What the Gallery tab's + needs (picker, cafe sources). Defaults to the
  /// app's; tests pass fakes.
  final GalleryFlowDeps Function(BuildContext context)? galleryFlows;

  /// Whether the Profile tab is the one on screen. Coming back to it reloads
  /// the profile behind what is already shown, so a review written elsewhere
  /// turns up without the page, its scroll position or its tab being reset.
  final bool isActive;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  ProfileCupsCubit? _cups;
  String? _cupsUser;

  /// The Cups grid for [userId], made once per signed-in person.
  ProfileCupsCubit _cupsFor(String userId, String username) {
    final given = widget.cupsCubit;
    if (given != null) {
      if (given.state.status == ProfileCupsStatus.initial) given.load();
      return given;
    }
    final current = _cups;
    if (current != null && _cupsUser == userId) return current;
    current?.close();
    _cupsUser = userId;
    if (!sl.isRegistered<ICupsRepository>()) {
      // No Cups backend wired (a test host): build the grid from what this
      // screen already has, your reviews and your gallery.
      return _cups = ProfileCupsCubit.from(() async {
        final profile = context.read<ProfileCubit>().state;
        return ProfileCups(
          userId: userId,
          isSelf: true,
          cafes: LegacyCups.profileCafes(
            userId: userId,
            username: username,
            isMine: true,
            reviews: profile is ProfileLoaded ? profile.reviews : const [],
            photos: context.read<GalleryCubit>().state.photos,
          ),
        );
      })..load();
    }
    return _cups = ProfileCupsCubit(
      repository: sl<ICupsRepository>(),
      userId: userId,
      username: username,
    )..load();
  }

  void _reloadCups() {
    (widget.cupsCubit ?? _cups)?.load(refresh: true);
    context.read<GalleryCubit>().load(refresh: true);
  }

  @override
  void dispose() {
    _cups?.close();
    super.dispose();
  }

  Future<void> _addCup() async {
    await addPhotosToGallery(context, _galleryDeps());
    if (mounted) _reloadCups();
  }

  void _openCafeCups(ProfileCafeCups cafe) {
    showProfileCafeCups(
      context,
      cafe: cafe,
      onOpenCafe: () => _openCafe(cafe.cafeId),
      onEdit: (cup) async {
        final outcome = await openCupComposer(
          context,
          cafe: PickedCafe(
            id: cafe.cafeId,
            name: cafe.cafeName,
            area: cafe.cafeArea,
            imageUrl: cafe.cafeImageUrl,
          ),
          source: CupSource.profile,
          editing: cup,
        );
        if (outcome != null && mounted) _reloadCups();
      },
      onChanged: _reloadCups,
      onOpenPhoto: (cup, index) {
        final id = cup.photos[index].id;
        final photo = context
            .read<GalleryCubit>()
            .state
            .photos
            .where((p) => p.id == id)
            .firstOrNull;
        if (photo == null) return false;
        // Your own photos open where they can be pinned and hidden.
        GalleryViewerPage.open(context, photo: photo, onOpenCafe: _openCafe);
        return true;
      },
    );
  }

  @override
  void initState() {
    super.initState();
    // The header shows the list count, so the lists load with the profile
    // rather than when the Lists tab is first opened. Sign-in loads them
    // too, so they are usually here already (or on their way).
    final listsBloc = context.read<ListsBloc>();
    if (context.read<ProfileCubit>().state is! ProfileUnauthenticated &&
        listsBloc.userLists.isEmpty &&
        listsBloc.state is! ListsLoading) {
      listsBloc.add(LoadUserLists());
    }
    final gallery = context.read<GalleryCubit>();
    if (context.read<ProfileCubit>().state is! ProfileUnauthenticated &&
        gallery.state.status == GalleryStatus.initial) {
      gallery.load();
    }
    final visibility = context.read<ProfileVisibilityCubit>();
    if (context.read<ProfileCubit>().state is! ProfileUnauthenticated &&
        visibility.state.status == ProfileVisibilityStatus.initial) {
      visibility.load();
    }
  }

  void _share(ProfileLoaded profile) {
    final share =
        widget.shareProfile ??
        ({required username, required name, own = false}) => sl<ShareService>()
            .shareProfile(username: username, name: name, own: own);
    share(
      username: profile.username,
      name: profileDisplayName(profile.name, profile.username),
      own: true,
    );
  }

  /// Share profile opens what the link shows and who sees it, not only the
  /// share sheet: Share, See what visitors see, and the gallery switch.
  /// Preview and privacy were otherwise only behind the Ranked tab's hint
  /// and Settings (launch-review/profile-ux.md, finding 10).
  Future<void> _shareOptions(ProfileLoaded profile) async {
    final public = context
        .read<ProfileVisibilityCubit>()
        .state
        .highlightsPublic;
    final choice = await ListsSheet.show<_ShareOption>(
      context,
      builder: (sheetContext) => ListsSheet(
        title: 'Your profile',
        gap: 4,
        children: [
          ListsSheetAction(
            title: 'Share profile',
            subtitle: 'Send a link to your profile',
            onTap: () => Navigator.pop(sheetContext, _ShareOption.share),
          ),
          ListsSheetAction(
            title: 'See what visitors see',
            subtitle: 'Your profile as anyone else sees it',
            onTap: () => Navigator.pop(sheetContext, _ShareOption.preview),
          ),
          ListsSheetAction(
            title: 'Cups privacy',
            subtitle: public
                ? 'Visitors see your cups. Change it in Settings.'
                : 'Your cups are hidden from visitors. Change it in '
                      'Settings.',
            onTap: () => Navigator.pop(sheetContext, _ShareOption.privacy),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _ShareOption.share:
        _share(profile);
      case _ShareOption.preview:
        _preview(profile);
      case _ShareOption.privacy:
        _openSettings();
    }
  }

  void _preview(ProfileLoaded profile) {
    final open = widget.openPreview;
    if (open != null) {
      open(profile.userId);
      return;
    }
    PublicProfilePage.open(
      context,
      userId: profile.userId,
      preview: true,
      source: ProfileViewSource.preview,
    );
  }

  @override
  void didUpdateWidget(covariant ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      context.read<ProfileCubit>().loadProfile(refresh: true);
      _reloadCups();
      // The sign-in prefetch may have failed (offline): try again, so the
      // Ranked count stops being a dash.
      final ranking = context.read<CafeRankingCubit>();
      if (!ranking.state.loaded) ranking.load();
    }
  }

  GalleryFlowDeps _galleryDeps() =>
      widget.galleryFlows?.call(context) ??
      GalleryFlowDeps(
        cubit: context.read<GalleryCubit>(),
        picker: sl<GalleryPhotoPicker>(),
        cafes: sl<ICafePickerSource>(),
      );

  void _openCafe(String cafeId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CafeDetailsPage(cafeId: cafeId)),
    );
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
  }

  void _openEdit() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<ProfileCubit>()),
            BlocProvider.value(value: context.read<AvatarUploadBloc>()),
          ],
          child: const EditProfilePage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileTokens.surface,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            if (state is ProfileUnauthenticated) return _signedOut();
            if (state is ProfileError) return _failed(state.error);
            return _profile(state);
          },
        ),
      ),
    );
  }

  /// The guest branch: say what an account is for and link to sign-in.
  Widget _signedOut() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProfileTopBar(title: 'Profile', brand: false),
        Expanded(
          child: SingleChildScrollView(
            child: ProfileMessage(
              icon: LucideIcons.user,
              title: 'Sign in to see your profile',
              subtitle:
                  'Keep your cups, lists and the places you have been in '
                  'one place.',
              actionLabel: 'Sign in or create account',
              actionStyle: ProfilePillStyle.brand,
              wideAction: true,
              onAction: () => context.push('/login'),
              top: 150,
            ),
          ),
        ),
      ],
    );
  }

  Widget _failed(Object error) {
    final info = AppErrorCopy.fromException(error);
    final signedOut = info.type == ErrorType.sessionExpired;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileTopBar(
          title: 'Profile',
          brand: false,
          onSettings: _openSettings,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: signedOut
                ? ProfileMessage.error(
                    title: info.title,
                    subtitle: info.subtitle,
                    actionLabel: 'Sign in',
                    onAction: () => context.push('/login'),
                    top: 180,
                  )
                : info.type == ErrorType.offline
                // Offline reads as offline, as on Home, not as our fault.
                // The same block as Home's, so being offline looks the
                // same on every tab.
                ? Padding(
                    padding: const EdgeInsets.only(top: 180, bottom: 24),
                    child: HomeStateView.error(
                      error: info,
                      onRetry: () => context.read<ProfileCubit>().loadProfile(),
                    ),
                  )
                : ProfileMessage.error(
                    title: 'Something went wrong',
                    subtitle:
                        'We could not load your profile. Check your '
                        'connection and try again.',
                    onAction: () => context.read<ProfileCubit>().loadProfile(),
                    top: 180,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _profile(ProfileState state) {
    final loaded = state is ProfileLoaded ? state : null;
    final cupsCubit = loaded == null || loaded.userId.isEmpty
        ? null
        : _cupsFor(loaded.userId, loaded.username);

    return BlocBuilder<ListsBloc, ListsState>(
      builder: (context, listsState) {
        final bloc = context.read<ListsBloc>();
        final lists = listsState is ListsLoaded
            ? listsState.lists
            : bloc.userLists;
        final been = lists.where((l) => l.listType == 'been').firstOrNull;
        // Unknown (a dash), not zero, until the ranking has loaded.
        final ranking = context.watch<CafeRankingCubit>().state;
        final rankedCount = ranking.loaded ? ranking.rankings.length : null;

        Widget page(ProfileCupsState? cups) {
          final cupsLoaded =
              cups != null && cups.status == ProfileCupsStatus.loaded;
          return DefaultTabController(
            length: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileTopBar(
                  title: loaded == null ? '@…' : '@${loaded.username}',
                  onSettings: _openSettings,
                ),
                Expanded(
                  child: Builder(
                    builder: (context) => NestedScrollView(
                      headerSliverBuilder: (context, _) => [
                        SliverToBoxAdapter(
                          child: loaded == null
                              ? const ProfileHeaderSkeleton()
                              : ProfileHeader(
                                  name: profileDisplayName(
                                    loaded.name,
                                    loaded.username,
                                  ),
                                  avatarUrl: loaded.avatarUrl,
                                  bio: loaded.bio,
                                  stats: [
                                    ProfileStat(
                                      'Ranked',
                                      rankedCount,
                                      onTap: () => DefaultTabController.of(
                                        context,
                                      ).animateTo(1),
                                    ),
                                    // Unknown (a dash), not zero, until the
                                    // cups have loaded.
                                    ProfileStat(
                                      'Cups',
                                      cupsLoaded
                                          ? cups.cups?.cupCount ?? 0
                                          : null,
                                      onTap: () => DefaultTabController.of(
                                        context,
                                      ).animateTo(0),
                                    ),
                                    ProfileStat(
                                      'Cafes',
                                      cupsLoaded
                                          ? cups.cups?.cafeCount ?? 0
                                          : null,
                                      onTap: () => DefaultTabController.of(
                                        context,
                                      ).animateTo(0),
                                    ),
                                  ],
                                  onEdit: _openEdit,
                                  // No handle yet (mid sign-up): nothing
                                  // to link to.
                                  onShare: loaded.username.isEmpty
                                      ? null
                                      : () => _shareOptions(loaded),
                                  onAdd: _addCup,
                                ),
                        ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _PinnedTabs(
                            height: ProfileTabs.heightFor(
                              MediaQuery.textScalerOf(context),
                            ),
                            child: ProfileTabs(
                              controller: DefaultTabController.of(context),
                              // Cups first, as the profile's public face;
                              // counts are in the header's stat row. Reviews
                              // live in Cups now (a review is a cup).
                              tabs: const [
                                ProfileTabData(
                                  'Cups',
                                  icon: PhosphorIcons.gridFour,
                                ),
                                ProfileTabData(
                                  'Ranked',
                                  private: true,
                                  icon: PhosphorIcons.trophy,
                                ),
                                ProfileTabData(
                                  'Lists',
                                  icon: PhosphorIcons.bookmarksSimple,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      body: TabBarView(
                        children: [
                          if (cupsCubit == null)
                            const SingleChildScrollView(
                              child: ProfileCupsSkeleton(),
                            )
                          else
                            BlocProvider.value(
                              value: cupsCubit,
                              child: ProfileCupsGrid(
                                isSelf: true,
                                onAdd: _addCup,
                                onOpen: _openCafeCups,
                              ),
                            ),
                          ProfileRankedTab(
                            beenListId: been?.id,
                            onPreview: loaded == null
                                ? null
                                : () => _preview(loaded),
                          ),
                          const ProfileListsTab(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        if (cupsCubit == null) return page(null);
        return BlocBuilder<ProfileCupsCubit, ProfileCupsState>(
          bloc: cupsCubit,
          builder: (_, cups) => page(cups),
        );
      },
    );
  }
}

/// Keeps [ProfileTabs] pinned under the top bar while the tab scrolls.
class _PinnedTabs extends SliverPersistentHeaderDelegate {
  const _PinnedTabs({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(_PinnedTabs oldDelegate) =>
      child != oldDelegate.child || height != oldDelegate.height;
}

enum _ShareOption { share, preview, privacy }
