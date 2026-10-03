import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/use_cases/get_reviews_written_by_user_usecase.dart';
import 'package:nook/core/cafe/presentation/cafe_ranking_cubit.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/features/profile/bloc/avatar_upload_bloc.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:nook/features/profile/presentation/pages/editprofile_page.dart';
import 'package:nook/features/profile/presentation/pages/reviews_page.dart';
import 'package:nook/features/profile/presentation/pages/settings_page.dart';
import 'package:nook/features/profile/presentation/profile_logic.dart';
import 'package:nook/features/profile/presentation/widgets/profile_header.dart';
import 'package:nook/features/profile/presentation/widgets/profile_lists_tab.dart';
import 'package:nook/features/profile/presentation/widgets/profile_review_sheets.dart';
import 'package:nook/features/profile/presentation/widgets/profile_reviews_tab.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ranked_tab.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
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
            current is AuthAccountDeleted,
        listener: (context, state) {
          context.read<ProfileCubit>().clear();
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
  const ProfileView({super.key, this.isActive = true});

  /// Whether the Profile tab is the one on screen. Coming back to it reloads
  /// the profile behind what is already shown, so a review written elsewhere
  /// turns up without the page, its scroll position or its tab being reset.
  final bool isActive;

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
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
  }

  @override
  void didUpdateWidget(covariant ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      context.read<ProfileCubit>().loadProfile(refresh: true);
    }
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

  void _openReviews() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ProfileCubit>(),
          child: const ReviewsPage(),
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
                  'Keep your reviews, lists and the places you have been in '
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
    final reviews = loaded?.reviews ?? const <WrittenReview>[];

    return BlocBuilder<ListsBloc, ListsState>(
      builder: (context, listsState) {
        final bloc = context.read<ListsBloc>();
        final lists = listsState is ListsLoaded
            ? listsState.lists
            : bloc.userLists;
        final been = lists.where((l) => l.listType == 'been').firstOrNull;
        final rankedCount = context
            .watch<CafeRankingCubit>()
            .state
            .rankings
            .length;
        // Unknown until the lists have loaded at least once.
        final listCount = listsState is ListsLoaded || lists.isNotEmpty
            ? lists.length
            : null;

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
                            : BlocBuilder<CafeRankingCubit, CafeRankingState>(
                                buildWhen: (a, b) =>
                                    a.rankings.length != b.rankings.length,
                                builder: (context, ranking) => ProfileHeader(
                                  name: loaded.name,
                                  avatarUrl: loaded.avatarUrl,
                                  bio: loaded.bio,
                                  countsLine: profileCountsLine(
                                    reviews: reviews.length,
                                    lists: listCount,
                                    ranked: ranking.rankings.length,
                                  ),
                                  onEdit: _openEdit,
                                ),
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
                            tabs: [
                              ProfileTabData(
                                'Ranked',
                                count: loaded == null ? null : rankedCount,
                              ),
                              ProfileTabData(
                                'Reviews',
                                // Unknown, not zero, when the read failed.
                                count: loaded == null || loaded.reviewsFailed
                                    ? null
                                    : reviews.length,
                              ),
                              ProfileTabData(
                                'Lists',
                                count: loaded == null ? null : listCount,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(
                      children: [
                        ProfileRankedTab(beenListId: been?.id),
                        ProfileReviewsTab(
                          loading: loaded == null,
                          failed: loaded?.reviewsFailed ?? false,
                          onRetry: () =>
                              context.read<ProfileCubit>().loadProfile(),
                          reviews: reviews,
                          onMore: (review) =>
                              showProfileReviewOptions(context, review),
                          onSeeAll: _openReviews,
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
