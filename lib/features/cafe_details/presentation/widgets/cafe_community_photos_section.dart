import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/profile_events.dart';
import 'package:nook/core/cafe/domain/entities/cafe_status.dart';
import 'package:nook/core/cafe/presentation/cafe_status_cubit.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_photos_page.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/gallery/data/gallery_photo_picker.dart';
import 'package:nook/features/gallery/domain/entities/community_photo.dart';
import 'package:nook/features/gallery/domain/entities/picked_cafe.dart';
import 'package:nook/features/gallery/domain/i_cafe_picker_source.dart';
import 'package:nook/features/gallery/presentation/cubit/cafe_photos_cubit.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/gallery_flows.dart';
import 'package:nook/features/gallery/presentation/pages/gallery_viewer_page.dart';
import 'package:nook/features/gallery/presentation/widgets/community_photo_actions.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_image.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:nook/injection_container.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Adds a photo of [cafe] to the signed-in person's gallery. True when one
/// was added.
typedef AddCafePhoto =
    Future<bool> Function(BuildContext context, PickedCafe cafe);

/// "Community photos": gallery photos other people added for this cafe,
/// newest first, each credited to who added it (docs/ux/
/// cafe-community-photos.md; TikTok's header row and strip, Luma's caption
/// under each tile; docs/references/cafe-community-photos).
///
/// Draws its own divider, so it can leave the page entirely: on a failed
/// load (the rest of the page is what matters), and on a cafe with no
/// photos unless the person has been there, when it asks for the first.
class CafeCommunityPhotosSection extends StatelessWidget {
  const CafeCommunityPhotosSection({
    super.key,
    required this.cafeId,
    required this.cafeName,
    this.cafeArea,
    this.cafeImageUrl,
    this.cubit,
    this.addPhoto,
  });

  final String cafeId;
  final String cafeName;
  final String? cafeArea;
  final String? cafeImageUrl;

  /// For tests; the app builds one per page.
  final CafePhotosCubit? cubit;

  /// For tests; the app runs the gallery's add flow.
  final AddCafePhoto? addPhoto;

  @override
  Widget build(BuildContext context) {
    final given = cubit;
    if (given != null) {
      return BlocProvider.value(
        value: given,
        child: _Body(section: this),
      );
    }
    return BlocProvider(
      create: (_) => sl<CafePhotosCubit>(param1: cafeId)..load(),
      child: _Body(section: this),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.section});

  final CafeCommunityPhotosSection section;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  bool _loggedView = false;

  String get _cafeId => widget.section.cafeId;

  /// The app's add flow, when the gallery is set up (not in most tests).
  AddCafePhoto? get _addPhoto {
    final given = widget.section.addPhoto;
    if (given != null) return given;
    if (!sl.isRegistered<GalleryCubit>() ||
        !sl.isRegistered<GalleryPhotoPicker>() ||
        !sl.isRegistered<ICafePickerSource>()) {
      return null;
    }
    return (context, cafe) async {
      final deps = GalleryFlowDeps(
        cubit: sl<GalleryCubit>(),
        picker: sl<GalleryPhotoPicker>(),
        cafes: sl<ICafePickerSource>(),
      );
      return await addCafePhoto(context, deps, cafe: cafe) != null;
    };
  }

  Future<void> _add(AddCafePhoto add) async {
    logAppEvent(
      CafePhotoEvents.addTapped,
      properties: {'cafe_id': _cafeId, 'surface': CafePhotoSurface.strip},
    );
    final section = widget.section;
    final cubit = context.read<CafePhotosCubit>();
    final added = await add(
      context,
      PickedCafe(
        id: section.cafeId,
        name: section.cafeName,
        area: section.cafeArea,
        imageUrl: section.cafeImageUrl,
      ),
    );
    if (added && mounted) await cubit.load(refresh: true);
  }

  void _openAll(CafePhotosState state) {
    logAppEvent(
      CafePhotoEvents.seeAllTapped,
      properties: {'cafe_id': _cafeId, 'surface': CafePhotoSurface.strip},
    );
    CafePhotosPage.open(
      context,
      cafeId: _cafeId,
      cafeName: widget.section.cafeName,
      seed: state,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CafePhotosCubit, CafePhotosState>(
      listenWhen: (_, now) =>
          !_loggedView &&
          now.status == CafePhotosStatus.loaded &&
          now.photos.isNotEmpty,
      listener: (_, state) {
        _loggedView = true;
        logAppEvent(
          CafePhotoEvents.viewed,
          properties: {
            'cafe_id': _cafeId,
            'surface': CafePhotoSurface.strip,
            'count': state.total,
          },
        );
      },
      builder: (context, state) {
        final Widget? content = switch (state.status) {
          CafePhotosStatus.initial ||
          CafePhotosStatus.loading => const _StripSkeleton(),
          // Quietly gone: photos are a bonus, not what the page is for.
          CafePhotosStatus.failed => null,
          // Brings its own divider: it may turn out to be nothing.
          CafePhotosStatus.loaded when state.photos.isEmpty => _emptyPrompt(),
          CafePhotosStatus.loaded => _Strip(
            state: state,
            cafeId: _cafeId,
            onSeeAll: () => _openAll(state),
          ),
        };
        if (content == null) return const SizedBox.shrink();
        if (state.isEmpty) return content;
        return _withDivider(content);
      },
    );
  }

  /// Only for someone who has been: they are the ones with a photo to
  /// add. Everyone else sees nothing rather than an empty box on most
  /// cafes.
  Widget? _emptyPrompt() {
    final add = _addPhoto;
    if (add == null) return null;
    return BlocBuilder<CafeStatusCubit, CafeStatusState>(
      buildWhen: (a, b) => a.statusFor(_cafeId) != b.statusFor(_cafeId),
      builder: (context, statuses) {
        if (statuses.statusFor(_cafeId) != CafeStatus.been) {
          return const SizedBox.shrink();
        }
        return _withDivider(_EmptyPrompt(onAdd: () => _add(add)));
      },
    );
  }
}

Widget _withDivider(Widget child) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [const CafeSectionDivider(), child],
);

/// The title row: name, count, and "See all" at the trailing edge.
class _Header extends StatelessWidget {
  const _Header({required this.total, this.onSeeAll});

  final int total;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final seeAll = onSeeAll;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CafeDetailsTokens.gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // The title takes what it needs; "See all" keeps its width.
          Expanded(
            child: Row(
              children: [
                const Flexible(child: CafeSectionTitle('Community photos')),
                if (total > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$total',
                    style: theme.bodyLarge?.copyWith(
                      fontSize: 16,
                      color: CafeDetailsTokens.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (seeAll != null)
            Semantics(
              button: true,
              label: 'See all $total community photos',
              excludeSemantics: true,
              child: AdaptiveTap(
                onTap: seeAll,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'See all',
                          style: theme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: CafeDetailsTokens.brand,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: CafeDetailsTokens.brand,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The photos in one row that runs off the right edge, so it reads as
/// more to swipe; "See all" ends it when the cafe has more than it holds.
class _Strip extends StatelessWidget {
  const _Strip({
    required this.state,
    required this.cafeId,
    required this.onSeeAll,
  });

  final CafePhotosState state;
  final String cafeId;
  final VoidCallback onSeeAll;

  /// About two and a half tiles on a phone: the cut-off third says swipe.
  static const tileWidth = 132.0;

  @override
  Widget build(BuildContext context) {
    final photos = state.photos;
    // More than two never all fit beside each other.
    final showSeeAll = state.total > 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(total: state.total, onSeeAll: showSeeAll ? onSeeAll : null),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: CafeDetailsTokens.gutter,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < photos.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                SizedBox(
                  width: tileWidth,
                  child: CommunityPhotoTile(
                    photo: photos[i],
                    onOpen: () => openCommunityPhotoViewer(
                      context,
                      photos: photos,
                      index: i,
                      cafeId: cafeId,
                      surface: CafePhotoSurface.strip,
                    ),
                    onOpenAuthor: () => openPhotoAuthor(
                      context,
                      photos[i].credit,
                      cafeId: cafeId,
                      surface: CafePhotoSurface.strip,
                    ),
                  ),
                ),
              ],
              if (state.hasMore) ...[
                const SizedBox(width: 10),
                _SeeAllTile(total: state.total, onTap: onSeeAll),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One community photo: the photo, then a caption with what it was (or
/// when) and who added it. The photo opens the viewer; the caption opens
/// their profile. Shared by the strip and the "See all" grid.
class CommunityPhotoTile extends StatelessWidget {
  const CommunityPhotoTile({
    super.key,
    required this.photo,
    required this.onOpen,
    required this.onOpenAuthor,
  });

  final CommunityPhoto photo;
  final VoidCallback onOpen;
  final VoidCallback onOpenAuthor;

  static const aspect = 4 / 5;
  static const radius = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final credit = photo.credit;
    final drink = photo.photo.drinkName?.trim();
    final what = drink == null || drink.isEmpty
        ? galleryMonthLabel(photo.photo.takenAt)
        : drink;
    final label = credit.isSelf ? 'Added by you' : 'Added by ${credit.label}';

    final caption = Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            what,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CafeDetailsTokens.ink,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ProfileAvatar(
                name: credit.username,
                size: 20,
                imageUrl: credit.avatarUrl,
                initialSize: 10,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  credit.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: credit.isSelf
                        ? CafeDetailsTokens.brand
                        : CafeDetailsTokens.muted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          image: true,
          label: '$what, ${label.toLowerCase()}. Open photo',
          excludeSemantics: true,
          child: AdaptiveTap(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(radius),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: AspectRatio(
                aspectRatio: aspect,
                child: LayoutBuilder(
                  builder: (context, box) => GalleryImage(
                    url: photo.photo.imageUrl,
                    cacheWidth: math.max(
                      1,
                      (box.maxWidth * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (credit.isSelf)
          Semantics(label: label, excludeSemantics: true, child: caption)
        else
          Semantics(
            button: true,
            label: 'Open ${credit.label}’s profile',
            excludeSemantics: true,
            child: AdaptiveTap(
              onTap: onOpenAuthor,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: caption,
              ),
            ),
          ),
      ],
    );
  }
}

/// The strip's last tile when the cafe has more photos than it holds.
class _SeeAllTile extends StatelessWidget {
  const _SeeAllTile({required this.total, required this.onTap});

  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'See all $total community photos',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CommunityPhotoTile.radius),
        child: Container(
          width: _Strip.tileWidth,
          height: _Strip.tileWidth / CommunityPhotoTile.aspect,
          decoration: BoxDecoration(
            border: Border.all(color: CafeDetailsTokens.border),
            borderRadius: BorderRadius.circular(CommunityPhotoTile.radius),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.layoutGrid,
                size: 22,
                color: CafeDetailsTokens.brand,
              ),
              const SizedBox(height: 8),
              Text(
                'See all',
                style: theme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CafeDetailsTokens.brand,
                ),
              ),
              Text(
                '$total photos',
                style: theme.bodySmall?.copyWith(
                  fontSize: 12,
                  color: CafeDetailsTokens.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// No photos yet, for someone who has been: ask for the first one.
class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(total: 0),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CafeDetailsTokens.gutter,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: CafeDetailsTokens.tint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.camera,
                  size: 20,
                  color: CafeDetailsTokens.ink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No photos yet',
                      style: theme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: CafeDetailsTokens.ink,
                      ),
                    ),
                    Text(
                      'Be the first to add one from your visit.',
                      style: theme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: CafeDetailsTokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: 'Add a photo',
                excludeSemantics: true,
                child: AdaptiveTap(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(999),
                  // 32 tall as drawn, 44 to touch, like "Write a review".
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: CafeDetailsTokens.brand),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Add a photo',
                        style: theme.bodyMedium?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CafeDetailsTokens.brand,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The strip's shape while it loads: title, then three tiles with their
/// caption lines, so nothing jumps when the photos arrive.
class _StripSkeleton extends StatelessWidget {
  const _StripSkeleton();

  @override
  Widget build(BuildContext context) {
    const tileHeight = _Strip.tileWidth / CommunityPhotoTile.aspect;
    return Semantics(
      label: 'Loading community photos',
      child: Skeletonizer.zone(
        effect: const PulseEffect(
          from: CafeDetailsTokens.tint,
          to: Color(0xFFF6F6F6),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: CafeDetailsTokens.gutter,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Bone(width: 160, height: 18, uniRadius: 6),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone(
                          width: _Strip.tileWidth,
                          height: tileHeight,
                          uniRadius: CommunityPhotoTile.radius,
                        ),
                        SizedBox(height: 10),
                        Bone(width: 96, height: 12, uniRadius: 6),
                        SizedBox(height: 8),
                        Bone(width: 72, height: 12, uniRadius: 6),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
