import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/use_cases/get_reviews_written_by_user_usecase.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/widgets/error/section_empty_widget.dart';
import 'package:nook/features/lists/bloc/lists_bloc.dart';
import 'package:nook/features/lists/bloc/lists_event.dart';
import 'package:nook/features/lists/bloc/lists_state.dart';
import 'package:nook/features/lists/presentation/pages/list_detail_page.dart';
import 'package:nook/features/lists/presentation/pages/list_page.dart';
import 'package:nook/features/profile/bloc/avatar_upload_bloc.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:nook/features/profile/presentation/pages/editprofile_page.dart';
import 'package:nook/features/profile/presentation/pages/reviews_page.dart';
import 'package:nook/features/profile/presentation/pages/settings_page.dart';
import 'package:nook/features/profile/presentation/widgets/review_card.dart';
import 'package:nook/injection_container.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRedesignPage extends StatelessWidget {
  const ProfileRedesignPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ProfileCubit(
            client: Supabase.instance.client,
            getReviewsWrittenByUser: sl<GetReviewsWrittenByUserUseCase>(),
            updateProfileUseCase: sl(),
          )..loadProfile(),
        ),
        BlocProvider(create: (_) => sl<AvatarUploadBloc>()),
      ],
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            title: BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, state) {
                final username = state is ProfileLoaded
                    ? state.username
                    : '...';
                return Text(
                  '@$username',
                  style: const TextStyle(
                    color: Color(0xFF344E41),
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
            actions: [
              IconButton(
                icon: Icon(PhosphorIcons.gearSix(), color: Colors.black87),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
            ],
          ),
          body: BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) {
              final isLoading =
                  state is ProfileLoading || state is ProfileInitial;
              final name = state is ProfileLoaded ? state.name : 'No Name';
              final avatarUrl = state is ProfileLoaded ? state.avatarUrl : '';
              final bio = state is ProfileLoaded ? state.bio : '';
              final username = state is ProfileLoaded ? state.username : '';
              final isReviewsLoading = isLoading;
              final writtenReviews = state is ProfileLoaded
                  ? state.reviews
                  : const <WrittenReview>[];
              final visibleReviews = writtenReviews.take(4).toList();

              return NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFF5F5F5),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child:
                                        (avatarUrl != null &&
                                            avatarUrl.isNotEmpty)
                                        ? Image.network(
                                            avatarUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, _, __) =>
                                                Icon(
                                                  PhosphorIcons.user(),
                                                  size: 32,
                                                  color: Colors.grey,
                                                ),
                                          )
                                        : Icon(
                                            PhosphorIcons.user(),
                                            size: 32,
                                            color: Colors.grey,
                                          ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (bio != null && bio.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  bio,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MultiBlocProvider(
                                          providers: [
                                            BlocProvider.value(
                                              value: context
                                                  .read<ProfileCubit>(),
                                            ),
                                            BlocProvider.value(
                                              value: context
                                                  .read<AvatarUploadBloc>(),
                                            ),
                                          ],
                                          child: const EditProfilePage(),
                                        ),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFF344E41),
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    foregroundColor: const Color(0xFF344E41),
                                  ),
                                  child: const Text(
                                    'Edit Profile',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyTabBarDelegate(
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          tabBarTheme: const TabBarThemeData(
                            dividerColor: Colors.transparent,
                            splashFactory: NoSplash.splashFactory,
                          ),
                        ),
                        child: const ColoredBox(
                          color: Colors.white,
                          child: TabBar(
                            isScrollable: true,
                            tabAlignment: TabAlignment.center,
                            indicatorColor: Color(0xFF344E41),
                            indicatorWeight: 3,

                            indicatorSize: TabBarIndicatorSize.label,
                            labelColor: Color(0xFF344E41),
                            unselectedLabelColor: Colors.grey,
                            dividerColor: Color(0xFFE0E0E0),
                            labelStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            unselectedLabelStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            tabs: [
                              Tab(text: 'Reviews'),
                              Tab(text: 'Collections'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    // ── Reviews Tab ──
                    _ReviewsTab(
                      isReviewsLoading: isReviewsLoading,
                      visibleReviews: visibleReviews,
                      username: username,
                      avatarUrl: avatarUrl ?? '',
                    ),

                    const _CollectionsTab(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Reviews Tab Widget ────────────────────────────────────────────────────────

class _ReviewsTab extends StatelessWidget {
  final bool isReviewsLoading;
  final List<WrittenReview> visibleReviews;
  final String username;
  final String avatarUrl;

  const _ReviewsTab({
    required this.isReviewsLoading,
    required this.visibleReviews,
    required this.username,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          if (isReviewsLoading)
            Skeletonizer(
              enabled: true,
              effect: const PulseEffect(),
              child: IgnorePointer(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, __) => const ReviewCard(
                    username: 'username',
                    cafeReviewed: 'Cafe name placeholder',
                    date: '00/00/00',
                    rating: 4.5,
                    reviewText:
                        'Review body placeholder text for skeleton layout while loading.',
                    photos: [],
                  ),
                ),
              ),
            )
          else if (visibleReviews.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 8, 22, 0),
              child: SizedBox(
                width: double.infinity,
                child: SectionEmptyWidget(
                  title: 'No reviews yet',
                  subtitle: 'When you share reviews, they will appear here.',
                  icon: Icons.chat_bubble_outline,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: visibleReviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final review = visibleReviews[index];
                return ReviewCard(
                  username: username,
                  avatarUrl: avatarUrl,
                  cafeReviewed: review.cafeName,
                  date: _formatReviewDate(review.createdAt),
                  rating: review.rating.toDouble(),
                  reviewText: review.content,
                  photos: review.imageUrls,
                );
              },
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Sticky Tab Bar Delegate ───────────────────────────────────────────────────

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  const _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => kToolbarHeight - 8;

  @override
  double get maxExtent => kToolbarHeight - 8;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) =>
      child != oldDelegate.child;
}

// ── See More Link ─────────────────────────────────────────────────────────────

class _SeeMoreLink extends StatefulWidget {
  final VoidCallback? onTap;

  const _SeeMoreLink({this.onTap});

  @override
  State<_SeeMoreLink> createState() => _SeeMoreLinkState();
}

class _SeeMoreLinkState extends State<_SeeMoreLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AdaptiveTap(
        onTap: widget.onTap,
        child: Text(
          'see more >',
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFF4CAF50),
            fontWeight: FontWeight.w400,
            decoration: _hovered
                ? TextDecoration.underline
                : TextDecoration.none,
            decorationColor: const Color(0xFF4CAF50),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _formatReviewDate(DateTime date) {
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  final yy = (date.year % 100).toString().padLeft(2, '0');
  return '$mm/$dd/$yy';
}

class _CollectionsTab extends StatefulWidget {
  const _CollectionsTab();

  @override
  State<_CollectionsTab> createState() => _CollectionsTabState();
}

class _CollectionsTabState extends State<_CollectionsTab> {
  late final ListsBloc _listsBloc;

  @override
  void initState() {
    super.initState();
    _listsBloc = sl<ListsBloc>()..add(LoadUserLists());
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _listsBloc,
      child: BlocBuilder<ListsBloc, ListsState>(
        builder: (context, state) {
          final lists = state is ListsLoaded
              ? state.lists
              : _listsBloc.userLists;
          final regularLists = lists
              .where((l) => !l.isDefault)
              .toList(growable: false);
          final isLoading = state is ListsLoading && lists.isEmpty;
          final isError = state is ListsError && lists.isEmpty;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // ── Create new collection row ──
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: _listsBloc,
                          child: const ListsPage(showBackButton: true),
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 20, color: Colors.black54),
                          SizedBox(width: 10),
                          Text(
                            'Create new collection',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (isLoading)
                    Skeletonizer(
                      enabled: true,
                      effect: const PulseEffect(),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.95,
                        children: const [
                          _CollectionPlaceholderTile(label: 'Loading...'),
                          _CollectionPlaceholderTile(label: 'Loading...'),
                          _CollectionPlaceholderTile(label: 'Loading...'),
                          _CollectionPlaceholderTile(label: 'Loading...'),
                        ],
                      ),
                    )
                  else if (isError)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.wifi_off_outlined,
                              size: 36,
                              color: Colors.black26,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Could not load collections.',
                              style: TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => _listsBloc.add(LoadUserLists()),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (regularLists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 48,
                        horizontal: 24,
                      ),
                      child: Center(
                        child: Text(
                          'Save your favourite cafes into collections. Tap + to create one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black45,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.95,
                          ),
                      itemCount: regularLists.length,
                      itemBuilder: (context, index) {
                        final list = regularLists[index];
                        return _CollectionGridTile(
                          title: list.name,
                          imageUrl: list.coverImageUrl,
                          cafeCount: list.cafeCount,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ListDetailPage(
                                listId: list.id,
                                title: list.name,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Real collection tile ──────────────────────────────────────────────────────

class _CollectionGridTile extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final int cafeCount;
  final VoidCallback onTap;

  const _CollectionGridTile({
    required this.title,
    required this.imageUrl,
    required this.cafeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl?.trim().isNotEmpty == true;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholderBg(),
              )
            else
              _buildPlaceholderBg(),
            // gradient + labels
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 28, 10, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xDD000000), Colors.transparent],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$cafeCount ${cafeCount == 1 ? 'place' : 'places'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8E8E8), Color(0xFF9E9E9E)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.coffee, color: Color(0xFFBDBDBD), size: 36),
      ),
    );
  }
}

class _CollectionPlaceholderTile extends StatelessWidget {
  final String label;

  const _CollectionPlaceholderTile({required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_cafe_outlined,
              size: 40,
              color: Color(0xFFCCCCCC),
            ),
          ),

          //  ── Bottom gradient + label ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
