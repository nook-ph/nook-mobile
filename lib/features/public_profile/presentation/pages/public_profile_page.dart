import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/block/block_cubit.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart'
    show WrittenReview;
import 'package:nook/core/services/share_service.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/profile/presentation/widgets/profile_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_actions_sheet.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_sheet_shell.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/domain/i_gallery_repository.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/pages/gallery_viewer_page.dart';
import 'package:nook/features/gallery/presentation/widgets/profile_gallery_tab.dart';
import 'package:nook/features/profile/presentation/widgets/profile_header.dart';
import 'package:nook/features/profile/presentation/widgets/profile_review_row.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/features/public_profile/domain/entities/public_profile.dart';
import 'package:nook/features/public_profile/domain/i_public_profile_repository.dart';
import 'package:nook/features/public_profile/presentation/cubit/public_profile_cubit.dart';
import 'package:nook/features/lists/presentation/widgets/lists_ui.dart';
import 'package:nook/injection_container.dart';

/// Shares [profile]'s web link. Swapped in tests.
typedef ShareProfile =
    Future<void> Function({
      required String username,
      required String name,
      bool own,
    });

/// Someone's profile as anyone else sees it: avatar, name, counts and bio,
/// then Gallery and Reviews. Never their ranking, their lists or any score
/// (nook-supabase docs/PUBLIC_PROFILE.md). The server still sends a Top 3;
/// profile v2 leaves it off so the photos start on the first screen.
///
/// With [preview] it is the owner's own "View as visitor": the same screen,
/// titled Preview, reached from their Ranked tab.
class PublicProfilePage extends StatelessWidget {
  const PublicProfilePage({
    super.key,
    this.username,
    this.userId,
    this.nameHint,
    this.preview = false,
    this.repository,
    this.shareProfile,
    this.onOpenCafe,
    this.isSignedIn,
  }) : assert(username != null || userId != null);

  /// Whether someone is signed in, for Block. Defaults to the session.
  final bool Function()? isSignedIn;

  final String? username;
  final String? userId;

  /// The name the opener already shows (a review's author), for the title
  /// while the profile loads.
  final String? nameHint;
  final bool preview;

  /// Defaults to the app's.
  final IPublicProfileRepository? repository;
  final ShareProfile? shareProfile;

  /// Defaults to pushing `/cafe/<id>`.
  final ValueChanged<String>? onOpenCafe;

  /// Pushes the profile for a review author, a crew member or a link.
  static Future<void> open(
    BuildContext context, {
    String? username,
    String? userId,
    String? nameHint,
    bool preview = false,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfilePage(
          username: username,
          userId: userId,
          nameHint: nameHint,
          preview: preview,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? sl<IPublicProfileRepository>();
    return BlocProvider(
      create: (_) => PublicProfileCubit(
        repository: repo,
        username: username,
        userId: userId,
      )..load(),
      child: _PublicProfileView(
        repository: repo,
        title: username != null ? '@$username' : (nameHint ?? ''),
        preview: preview,
        shareProfile:
            shareProfile ??
            ({required username, required name, own = false}) =>
                sl<ShareService>().shareProfile(
                  username: username,
                  name: name,
                  own: own,
                ),
        onOpenCafe: onOpenCafe,
        signedIn: (isSignedIn ?? _sessionSignedIn)(),
      ),
    );
  }

  static bool _sessionSignedIn() {
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }
}

class _PublicProfileView extends StatelessWidget {
  const _PublicProfileView({
    required this.repository,
    required this.title,
    required this.preview,
    required this.shareProfile,
    required this.signedIn,
    this.onOpenCafe,
  });

  final IPublicProfileRepository repository;
  final String title;
  final bool preview;
  final ShareProfile shareProfile;
  final bool signedIn;
  final ValueChanged<String>? onOpenCafe;

  /// Asks why, then reports the photo. Signed-in visitors only.
  Future<void> _reportPhoto(BuildContext context, GalleryPhoto photo) {
    return _report<PhotoReportReason>(
      context,
      title: 'Report this photo?',
      message:
          'For the photo or what it says. They won’t know who reported it.',
      reasons: PhotoReportReason.values,
      labelOf: (reason) => reason.label,
      send: (reason, details) =>
          repository.reportPhoto(photo.id, reason, details: details),
    );
  }

  /// Asks why, then reports the person: their name, avatar or bio.
  Future<void> _reportProfile(BuildContext context, PublicProfile profile) {
    return _report<ProfileReportReason>(
      context,
      title: 'Report @${profile.username}?',
      message:
          'For their name, photo or bio. To report a review or a photo, use '
          'its ⋯. They won’t know who reported them.',
      reasons: ProfileReportReason.values,
      labelOf: (reason) => reason.label,
      send: (reason, details) =>
          repository.reportProfile(profile.userId, reason, details: details),
    );
  }

  /// The app's one report sheet: a reason, an optional detail, then Submit
  /// report. Thanks the person once it is sent.
  Future<void> _report<T>(
    BuildContext context, {
    required String title,
    required String message,
    required List<T> reasons,
    required String Function(T) labelOf,
    required Future<void> Function(T reason, String? details) send,
  }) async {
    final sent = await ReviewSheetShell.show<bool>(
      context,
      builder: (_) => ReportReasonSheet<T>(
        title: title,
        message: message,
        reasons: reasons,
        labelOf: labelOf,
        onSubmit: (reason, details) =>
            send(reason, details.isEmpty ? null : details),
      ),
    );
    if (sent == true && context.mounted) {
      showPrimaryToast(context, ReviewReportSheet.sentMessage);
    }
  }

  /// ⋯ on one of their reviews: Report review or Block, as on a cafe page.
  /// Blocking there leaves this profile too.
  Future<void> _reviewOptions(
    BuildContext context,
    PublicProfile profile,
    WrittenReview review,
  ) async {
    final blocks = context.read<BlockCubit>();
    await showReviewActionsSheet(
      context,
      reviewId: review.id,
      cafeId: review.cafeId,
      authorId: profile.userId,
      authorName: profile.displayName,
    );
    if (context.mounted && blocks.isBlocked(profile.userId)) {
      Navigator.of(context).maybePop();
    }
  }

  /// The bar's ⋯ (Figma B2): Share profile, then Report and Block for a
  /// signed-in visitor.
  Future<void> _openOptions(BuildContext context, PublicProfile profile) async {
    final moderate = signedIn && !profile.isSelf;
    final choice = await ListsSheet.show<_ProfileOption>(
      context,
      builder: (sheetContext) => ListsSheet(
        title: '@${profile.username}',
        gap: 4,
        children: [
          ListsSheetAction(
            title: 'Share profile',
            subtitle: profile.isSelf
                ? 'Send a link to your profile'
                : 'Send a link to their profile',
            onTap: () => Navigator.pop(sheetContext, _ProfileOption.share),
          ),
          if (moderate) ...[
            ListsSheetAction(
              title: 'Report @${profile.username}',
              subtitle: 'Their name, photo or bio breaks the guidelines',
              onTap: () => Navigator.pop(sheetContext, _ProfileOption.report),
            ),
            ListsSheetAction(
              title: 'Block @${profile.username}',
              subtitle: 'Hide their reviews and profile from you',
              destructive: true,
              onTap: () => Navigator.pop(sheetContext, _ProfileOption.block),
            ),
          ],
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case _ProfileOption.share:
        await shareProfile(
          username: profile.username,
          name: profile.displayName,
          own: profile.isSelf,
        );
      case _ProfileOption.report:
        await _reportProfile(context, profile);
      case _ProfileOption.block:
        await _block(context, profile);
    }
  }

  /// Blocking from the profile, as from a review: they disappear from the
  /// viewer's feeds and their profile is no longer shown to them.
  Future<void> _block(BuildContext context, PublicProfile profile) async {
    final blocks = context.read<BlockCubit>();
    final confirmed = await showProfileConfirmSheet(
      context,
      title: 'Block @${profile.username}?',
      message:
          'You will no longer see their reviews or their profile. You can '
          'unblock them in Settings.',
      confirmLabel: 'Block',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await blocks.block(profile.userId);
      if (!context.mounted) return;
      showPrimaryToast(context, '@${profile.username} blocked');
      Navigator.of(context).maybePop();
    } catch (_) {
      if (context.mounted) {
        showPrimaryToast(context, 'Could not block them. Please try again.');
      }
    }
  }

  void _openCafe(BuildContext context, String id) {
    final open = onOpenCafe;
    if (open != null) {
      open(id);
    } else {
      context.push('/cafe/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PublicProfileCubit, PublicProfileState>(
      builder: (context, state) {
        final profile = state.profile;
        return Scaffold(
          backgroundColor: ProfileTokens.surface,
          appBar: ProfileNavBar(
            title: preview
                ? 'Preview'
                : (profile != null ? '@${profile.username}' : title),
            subtitle: preview ? 'What visitors see on your profile' : null,
            actions: [
              if (profile != null && !preview)
                AdaptiveTap(
                  onTap: () => _openOptions(context, profile),
                  borderRadius: BorderRadius.circular(22),
                  child: Semantics(
                    button: true,
                    label: 'Profile options',
                    child: const SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        LucideIcons.ellipsis,
                        size: 20,
                        color: ProfileTokens.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: switch (state.status) {
              PublicProfileStatus.loading => const _Loading(),
              PublicProfileStatus.notFound => const SingleChildScrollView(
                child: ProfileMessage(
                  icon: LucideIcons.userX,
                  title: 'This profile isn’t available',
                  subtitle:
                      'The link may be wrong, or the account is no longer '
                      'on Nook.',
                  top: 120,
                ),
              ),
              PublicProfileStatus.failed => SingleChildScrollView(
                child: ProfileMessage.error(
                  title: 'Could not load this profile',
                  subtitle: 'Check your connection and try again.',
                  onAction: () => context.read<PublicProfileCubit>().load(),
                  top: 120,
                ),
              ),
              PublicProfileStatus.loaded => _Loaded(
                profile: profile!,
                onOpenCafe: (id) => _openCafe(context, id),
                onReportPhoto: signedIn && !profile.isSelf && !preview
                    ? (photo) => _reportPhoto(context, photo)
                    : null,
                onReviewMore: signedIn && !profile.isSelf && !preview
                    ? (review) => _reviewOptions(context, profile, review)
                    : null,
              ),
            },
          ),
        );
      },
    );
  }
}

enum _ProfileOption { share, report, block }

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [ProfileHeaderSkeleton(showAction: false)],
      ),
    );
  }
}

/// A gallery that only reads: the visitor's photos, already loaded with
/// the profile. Lets the shared viewer run on someone else's photos.
class _ReadOnlyGallery implements IGalleryRepository {
  const _ReadOnlyGallery(this.photos);

  final List<GalleryPhoto> photos;

  @override
  Future<List<GalleryPhoto>> getMyPhotos() async => photos;

  @override
  Future<List<GalleryPhoto>> addPhotos({
    required String cafeId,
    required List<PickedGalleryPhoto> photos,
    required GalleryPhotoSource source,
    String? drinkName,
    String? caption,
  }) => throw UnsupportedError('Read only');

  @override
  Future<void> deletePhoto(String photoId) =>
      throw UnsupportedError('Read only');

  @override
  Future<void> setDetails(
    String photoId, {
    String? drinkName,
    String? caption,
    String? cafeId,
  }) => throw UnsupportedError('Read only');

  @override
  Future<void> setHidden(String photoId, {required bool hidden}) =>
      throw UnsupportedError('Read only');

  @override
  Future<void> setPinOrder(String photoId, int? pinOrder) =>
      throw UnsupportedError('Read only');
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.profile,
    required this.onOpenCafe,
    this.onReportPhoto,
    this.onReviewMore,
  });

  final PublicProfile profile;
  final ValueChanged<String> onOpenCafe;
  final ValueChanged<GalleryPhoto>? onReportPhoto;

  /// ⋯ on a review row. Null leaves it off (guests, Preview, yourself).
  final ValueChanged<WrittenReview>? onReviewMore;

  @override
  Widget build(BuildContext context) {
    final ranked = profile.rankedCount, cups = profile.cupCount;
    final header = [
      ProfileHeader(
        name: profile.displayName,
        avatarUrl: profile.avatarUrl,
        bio: profile.bio ?? '',
        // Ranked and Cups only when the owner shows them.
        stats: [
          if (ranked != null) ProfileStat('Ranked', ranked),
          ProfileStat('Reviews', profile.reviewCount),
          if (cups != null) ProfileStat('Cups', cups),
        ],
      ),
    ];

    if (!profile.highlightsPublic) {
      // The gallery is off: the profile is the reviews, which are
      // public on cafe pages anyway. No tabs for a single list.
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...header,
            const _PrivateNote(),
            const ProfileDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ProfileTokens.gutter,
                16,
                ProfileTokens.gutter,
                0,
              ),
              child: _ReviewsBody(
                profile: profile,
                onOpenCafe: onOpenCafe,
                onMore: onReviewMore,
                shrinkWrap: true,
              ),
            ),
          ],
        ),
      );
    }

    return BlocProvider(
      create: (_) =>
          GalleryCubit(repository: _ReadOnlyGallery(profile.photos))..load(),
      child: DefaultTabController(
        length: 2,
        child: Builder(
          builder: (context) => NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: header,
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
                    tabs: const [
                      ProfileTabData('Gallery'),
                      ProfileTabData('Reviews'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _GalleryBody(
                  profile: profile,
                  onOpenCafe: onOpenCafe,
                  onReportPhoto: onReportPhoto,
                  onOpenReviews: () =>
                      DefaultTabController.of(context).animateTo(1),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    ProfileTokens.gutter,
                    16,
                    ProfileTokens.gutter,
                    24,
                  ),
                  child: _ReviewsBody(
                    profile: profile,
                    onOpenCafe: onOpenCafe,
                    onMore: onReviewMore,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One muted line where the gallery would be.
class _PrivateNote extends StatelessWidget {
  const _PrivateNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        0,
        ProfileTokens.gutter,
        16,
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.lock, size: 16, color: ProfileTokens.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Their gallery is private. Their reviews are public.',
              style: ProfileTokens.text(13, color: ProfileTokens.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryBody extends StatelessWidget {
  const _GalleryBody({
    required this.profile,
    required this.onOpenCafe,
    required this.onOpenReviews,
    this.onReportPhoto,
  });

  final PublicProfile profile;
  final ValueChanged<String> onOpenCafe;
  final VoidCallback onOpenReviews;
  final ValueChanged<GalleryPhoto>? onReportPhoto;

  @override
  Widget build(BuildContext context) {
    final photos = profile.photos;
    if (photos.isEmpty) {
      return const SingleChildScrollView(
        child: ProfileMessage(
          icon: LucideIcons.coffee,
          title: 'No photos yet',
          subtitle: 'Photos of what they drink show up here.',
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: 1.5, bottom: 24),
          sliver: SliverGrid.builder(
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 1.5,
              crossAxisSpacing: 1.5,
              childAspectRatio: ProfileGalleryTab.tileAspect,
            ),
            itemBuilder: (context, i) => GalleryTile(
              key: ValueKey(photos[i].id),
              photo: photos[i],
              onTap: () => GalleryViewerPage.open(
                context,
                photo: photos[i],
                isOwner: false,
                onOpenCafe: onOpenCafe,
                onOpenReview: onOpenReviews,
                onReport: onReportPhoto,
                reviewTextOf: (photo) => profile.reviews
                    .where((r) => r.id == photo.sourceId)
                    .firstOrNull
                    ?.content,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewsBody extends StatelessWidget {
  const _ReviewsBody({
    required this.profile,
    required this.onOpenCafe,
    this.onMore,
    this.shrinkWrap = false,
  });

  final PublicProfile profile;
  final ValueChanged<String> onOpenCafe;
  final ValueChanged<WrittenReview>? onMore;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    if (profile.reviews.isEmpty) {
      return ProfileMessage(
        icon: LucideIcons.star,
        title: 'No reviews yet',
        subtitle: '${profile.displayName} hasn’t reviewed a cafe yet.',
        top: shrinkWrap ? 24 : 80,
      );
    }
    return ProfileReviewList(
      reviews: profile.reviews,
      onOpenCafe: onOpenCafe,
      onMore: onMore,
    );
  }
}

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
