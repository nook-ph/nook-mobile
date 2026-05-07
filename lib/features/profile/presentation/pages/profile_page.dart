import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final reviews = [
      {
        'name': 'Name Name Name',
        'date': '00/00/00',
        'rating': 4.9,
        'reviewText': 'The quick brown fox jumps over the lazy dog.',
        'photos': <String>[],
      },
      {
        'name': 'Name Name Name',
        'date': '00/00/00',
        'rating': 4.9,
        'reviewText': 'The quick brown fox jumps over the lazy dog.',
        'photos': <String>[],
      },
      {
        'name': 'Name Name Name',
        'date': '00/00/00',
        'rating': 3.5,
        'reviewText': 'The quick brown fox jumps over the lazy dog.',
        'photos': <String>[],
      },
      {
        'name': 'Name Name Name',
        'date': '00/00/00',
        'rating': 5.0,
        'reviewText': 'The quick brown fox jumps over the lazy dog.',
        'photos': <String>[],
      },
      {
        'name': 'Name Name Name',
        'date': '00/00/00',
        'rating': 2.0,
        'reviewText': 'Extra review that should not show.',
        'photos': <String>[],
      },
    ];

    final visibleReviews = reviews.take(4).toList();
    return BlocProvider(
      create: (_) =>
          ProfileCubit(client: Supabase.instance.client)..loadProfile(),
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

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      BlocBuilder<ProfileCubit, ProfileState>(
                        builder: (context, state) {
                          if (state is ProfileLoading ||
                              state is ProfileInitial) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 22),
                              child: SizedBox(
                                height: 80,
                                child: Center(
                                  child: CircularProgressIndicator(),
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
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReviewsPage(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (visibleReviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(
                            left: 22,
                            right: 22,
                            top: 8,
                          ),
                          child: SectionEmptyWidget(
                            title: 'No reviews yet',
                            subtitle:
                                'When you share reviews, they will appear here.',
                            icon: Icons.chat_bubble_outline,
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
                              name: review['name'] as String,
                              date: review['date'] as String,
                              rating: review['rating'] as double,
                              reviewText: review['reviewText'] as String,
                              photos: review['photos'] as List<String>,
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
