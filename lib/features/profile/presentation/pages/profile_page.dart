import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/use_cases/get_reviews_written_by_user_usecase.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/core/widgets/error/section_empty_widget.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/lists/presentation/pages/list_page.dart';
import 'package:nook/features/profile/presentation/widgets/review_card.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:nook/features/profile/presentation/pages/editprofile_page.dart';
import 'package:nook/features/profile/presentation/pages/reviews_page.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/injection_container.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit(
        client: Supabase.instance.client,
        getReviewsWrittenByUser: sl<GetReviewsWrittenByUserUseCase>(),
      )..loadProfile(),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            context.read<ProfileCubit>().loadProfile();
          }
          if (state is AuthUnauthenticated) {
            context.read<ProfileCubit>().clear();
            context.go('/login');
          }
          if (state is AuthError) {
            showPrimaryToast(context, state.message);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: BlocBuilder<ProfileCubit, ProfileState>(
              builder: (context, profileState) {
                if (profileState is ProfileError) {
                  final info = AppErrorCopy.fromException(profileState.error);
                  return FullPageErrorWidget(
                    error: info,
                    onRetry: info.type == ErrorType.sessionExpired
                        ? () => context.push('/login')
                        : () =>
                            context.read<ProfileCubit>().loadProfile(),
                  );
                }

                final isReviewsLoading = profileState is ProfileLoading ||
                    profileState is ProfileInitial;
                final writtenReviews = profileState is ProfileLoaded
                    ? profileState.reviews
                    : const <WrittenReview>[];
                final visibleReviews = writtenReviews.take(4).toList();

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      BlocBuilder<ProfileCubit, ProfileState>(
                        builder: (context, state) {
                          if (state is ProfileLoading ||
                              state is ProfileInitial) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 22),
                              child: Skeletonizer(
                                enabled: true,
                                effect: const PulseEffect(),
                                child: IgnorePointer(
                                  child: ProfileHeroSection(
                                    name: 'Display name placeholder',
                                    email: 'email.address.placeholder@example.com',
                                  ),
                                ),
                              ),
                            );
                          }

                          final name = state is ProfileLoaded
                              ? state.name
                              : 'No name';
                          final email = state is ProfileLoaded
                              ? state.email
                              : 'No email';

                          return ProfileHeroSection(
                            name: name,
                            email: email,
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Reviews',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            _SeeMoreLink(
                              onTap: () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => const ReviewsPage(),
                                  ),
                                );
                                if (!context.mounted) return;
                                context.read<ProfileCubit>().loadProfile();
                              },
                            ),
                          ],
                        ),
                      ),
                      if (isReviewsLoading)
                        Skeletonizer(
                          enabled: true,
                          effect: const PulseEffect(),
                          child: IgnorePointer(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 22),
                              itemCount: 3,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                return const ReviewCard(
                                  name: 'Cafe name placeholder',
                                  date: '00/00/00',
                                  rating: 4.5,
                                  reviewText:
                                      'Review body placeholder text for skeleton layout while loading.',
                                  photos: [],
                                );
                              },
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
                              subtitle:
                                  'When you share reviews, they will appear here.',
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
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final review = visibleReviews[index];
                            return ReviewCard(
                              name: review.cafeName,
                              date: _formatReviewDate(review.createdAt),
                              rating: review.rating.toDouble(),
                              reviewText: review.content,
                              photos: review.imageUrls,
                            );
                          },
                        ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SettingsTile(
                              label: 'My Lists',
                              iconData: PhosphorIcons.bookmarkSimple(),
                              iconColor: const Color(0xFF344E41),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ListsPage(),
                                  ),
                                );
                              },
                            ),
                            const Divider(
                              height: 1,
                              color: Color(0xFFE0E0E0),
                            ),
                            _SettingsTile(
                              label: 'Edit Profile',
                              iconData: PhosphorIcons.caretRight(),
                              iconColor: const Color(0xFF344E41),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const EditProfilePage(),
                                  ),
                                );
                              },
                            ),
                            const Divider(
                              height: 1,
                              color: Color(0xFFE0E0E0),
                            ),
                            _SettingsTile(
                              label: 'Logout',
                              iconData: PhosphorIcons.signOut(),
                              iconColor: Colors.red,
                              labelColor: Colors.black,
                              onTap: () => _showLogoutDialog(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileHeroSection extends StatelessWidget {
  final String name;
  final String email;

  const ProfileHeroSection({
    super.key,
    required this.name,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF344E41), width: 2.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2.5),
              child: Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE8E8E8),
                ),
                child: Icon(
                  PhosphorIcons.user(),
                  size: 40,
                  color: const Color(0xFFBDBDBD),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Name + bio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
      child: GestureDetector(
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

// --- Settings Tile ---
class _SettingsTile extends StatelessWidget {
  final String label;
  final PhosphorIconData iconData;
  final Color iconColor;
  final Color labelColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.label,
    required this.iconData,
    required this.iconColor,
    required this.onTap,
    this.labelColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: labelColor)),
            Icon(iconData, color: iconColor, size: 20),
          ],
        ),
      ),
    );
  }
}

String _formatReviewDate(DateTime date) {
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  final yy = (date.year % 100).toString().padLeft(2, '0');
  return '$mm/$dd/$yy';
}

// --- Logout Dialog ---
void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Log out',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      content: const Text('Are you sure you want to log out?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            context.read<AuthBloc>().add(const AuthSignOutEvent());
            Navigator.pop(ctx);
          },
          child: const Text('Log out', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
