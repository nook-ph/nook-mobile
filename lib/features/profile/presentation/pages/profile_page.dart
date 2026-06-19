import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/use_cases/get_reviews_written_by_user_usecase.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/core/widgets/error/full_page_error_widget.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/widgets/error/section_empty_widget.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:nook/features/lists/presentation/pages/list_page.dart';
import 'package:nook/features/profile/presentation/widgets/review_card.dart';
import 'package:nook/features/profile/presentation/cubit/profile_cubit.dart';
import 'package:nook/features/profile/presentation/pages/editprofile_page.dart';
import 'package:nook/features/profile/presentation/pages/reviews_page.dart';
import 'package:nook/features/profile/bloc/avatar_upload_bloc.dart';
import 'package:nook/features/profile/bloc/avatar_upload_event.dart';
import 'package:nook/features/profile/bloc/avatar_upload_state.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/injection_container.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
      child: MultiBlocListener(
        listeners: [
          BlocListener<AuthBloc, AuthState>(
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
          ),
          BlocListener<AvatarUploadBloc, AvatarUploadState>(
            listener: (context, state) {
              if (state is AvatarUploadSuccess) {
                showPrimaryToast(context, 'Avatar updated successfully!');
                context.read<ProfileCubit>().loadProfile();
              }
              if (state is AvatarUploadError) {
                showPrimaryToast(context, state.message);
              }
            },
          ),
        ],
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
                        : () => context.read<ProfileCubit>().loadProfile(),
                  );
                }

                final isReviewsLoading =
                    profileState is ProfileLoading ||
                    profileState is ProfileInitial;
                final writtenReviews = profileState is ProfileLoaded
                    ? profileState.reviews
                    : const <WrittenReview>[];
                final visibleReviews = writtenReviews.take(4).toList();
                final username = profileState is ProfileLoaded
                    ? profileState.username
                    : '';

                final avatarUrl = profileState is ProfileLoaded
                    ? profileState.avatarUrl
                    : '';

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // Profile Hero
                      BlocBuilder<ProfileCubit, ProfileState>(
                        builder: (context, state) {
                          if (state is ProfileLoading ||
                              state is ProfileInitial) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              child: Skeletonizer(
                                enabled: true,
                                effect: const PulseEffect(),
                                child: IgnorePointer(
                                  child: ProfileHeroSection(
                                    name: 'Display name placeholder',
                                    email:
                                        'email.address.placeholder@example.com',
                                    avatarUrl: null,
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
                          final avatarUrl = state is ProfileLoaded
                              ? state.avatarUrl
                              : null;

                          return ProfileHeroSection(
                            name: name,
                            email: email,
                            avatarUrl: avatarUrl,
                          );
                        },
                      ),
                      const SizedBox(height: 32),
                      // Reviews header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Reviews',
                              style: context.textTheme.titleMediumSemi,
                            ),
                            _SeeMoreLink(
                              onTap: () async {
                                await Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => BlocProvider.value(
                                      value: context.read<ProfileCubit>(),
                                      child: const ReviewsPage(),
                                    ),
                                  ),
                                );
                                if (!context.mounted) return;
                                context.read<ProfileCubit>().loadProfile();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Reviews list
                      if (isReviewsLoading)
                        Skeletonizer(
                          enabled: true,
                          effect: const PulseEffect(),
                          child: IgnorePointer(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                              ),
                              itemCount: 3,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
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
                      const SizedBox(height: 32),
                      // Settings
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settings',
                              style: context.textTheme.titleMediumSemi,
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
                            const Divider(height: 1, color: Color(0xFFE0E0E0)),
                            _SettingsTile(
                              label: 'Edit Profile',
                              iconData: PhosphorIcons.caretRight(),
                              iconColor: const Color(0xFF344E41),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MultiBlocProvider(
                                      providers: [
                                        BlocProvider.value(
                                          value: context.read<ProfileCubit>(),
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
                            ),
                            const Divider(height: 1, color: Color(0xFFE0E0E0)),
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
                      const SizedBox(height: 32),
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
  final String? avatarUrl;

  const ProfileHeroSection({
    super.key,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          EditableAvatar(avatarUrl: avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: context.textTheme.titleMediumSemi,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: context.textTheme.bodySmall!.copyWith(
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

class EditableAvatar extends StatefulWidget {
  final String? avatarUrl;

  const EditableAvatar({super.key, this.avatarUrl});

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  final ImagePicker _imagePicker = ImagePicker();

  Future<File> _compressAvatar(File file) async {
    final filePath = file.path;
    final ext = filePath.split('.').last.toLowerCase();
    final targetPath = filePath.replaceAll('.$ext', '_avatar_compressed.$ext');

    final result = await FlutterImageCompress.compressAndGetFile(
      filePath,
      targetPath,
      quality: 70,
      minWidth: 512,
      minHeight: 512,
      format: ext == 'png' ? CompressFormat.png : CompressFormat.jpeg,
    );

    return result == null ? file : File(result.path);
  }

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (picked == null) return;

    final compressedFile = await _compressAvatar(File(picked.path));

    String? accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      try {
        final refreshed = await Supabase.instance.client.auth.refreshSession();
        accessToken = refreshed.session?.accessToken;
      } catch (_) {}
    }

    if (!context.mounted) return;

    context.read<AvatarUploadBloc>().add(
      SubmitAvatarRequested(file: compressedFile, accessToken: accessToken),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AvatarUploadBloc, AvatarUploadState>(
      builder: (context, state) {
        final isUploading = state is AvatarUploading;

        return GestureDetector(
          onTap: isUploading ? null : () => _pickAndUploadAvatar(context),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF344E41),
                    width: 2.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    width: 75,
                    height: 75,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE8E8E8),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child:
                        widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                        ? Image.network(
                            widget.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              PhosphorIcons.user(),
                              size: 40,
                              color: const Color(0xFFBDBDBD),
                            ),
                          )
                        : Icon(
                            PhosphorIcons.user(),
                            size: 40,
                            color: const Color(0xFFBDBDBD),
                          ),
                  ),
                ),
              ),
              if (isUploading)
                Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(22.0),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF344E41),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 14,
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
          style: context.textTheme.bodySmall!.copyWith(
            color: const Color(0xFF4CAF50),
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
            Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: labelColor)),
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

void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log out',
              style: ctx.textTheme.titleMediumSemi,
            ),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to log out?',
              style: ctx.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AdaptiveTextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: Text(
                    'Cancel',
                    style: ctx.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                AdaptiveTextButton(
                  onPressed: () {
                    context.read<AuthBloc>().add(const AuthSignOutEvent());
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'Log out',
                    style: ctx.textTheme.bodyMedium?.copyWith(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
