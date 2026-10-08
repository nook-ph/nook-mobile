import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_image.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

/// The Gallery tab: a tight 3-column grid of 4:5 tiles with pinned photos
/// first (Instagram's grid, TikTok's Pinned tag; Tinder's dashed empty
/// slots; docs/references/coffee-gallery, profile-v2). The cup count and
/// the add button live in the profile header. Long-press a photo for its
/// options; tap to open it.
class ProfileGalleryTab extends StatelessWidget {
  const ProfileGalleryTab({
    super.key,
    required this.onAdd,
    required this.onOpen,
    required this.onOptions,
  });

  final VoidCallback onAdd;
  final ValueChanged<GalleryPhoto> onOpen;
  final ValueChanged<GalleryPhoto> onOptions;

  static const _gap = 1.5;

  /// Instagram's 4:5 profile tile.
  static const tileAspect = 4 / 5;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GalleryCubit, GalleryState>(
      builder: (context, state) {
        // Photos on their way in show even when the gallery itself isn't
        // loaded (still loading, or failed): a failed one says "Tap Retry
        // on it", so its tile has to be there.
        final uploadsOnly =
            state.status != GalleryStatus.loaded && state.uploads.isNotEmpty;
        switch (uploadsOnly ? GalleryStatus.loaded : state.status) {
          case GalleryStatus.initial || GalleryStatus.loading:
            return const _GridSkeleton();
          case GalleryStatus.failed:
            return SingleChildScrollView(
              child: ProfileMessage.error(
                title: 'Could not load your gallery.',
                subtitle: 'Check your connection and try again.',
                actionStyle: ProfilePillStyle.outlined,
                onAction: () => context.read<GalleryCubit>().load(),
              ),
            );
          case GalleryStatus.loaded:
            if (state.photos.isEmpty && state.uploads.isEmpty) {
              return _Empty(onAdd: onAdd);
            }
            // New photos land after the pinned ones, where they will be
            // seen, until their rows arrive (Figma E2).
            final pinned = state.photos.takeWhile((p) => p.isPinned).length;
            final items = <Object>[
              ...state.photos.take(pinned),
              ...state.uploads,
              ...state.photos.skip(pinned),
            ];
            return CustomScrollView(
              slivers: [
                if (uploadsOnly && state.status == GalleryStatus.failed)
                  SliverToBoxAdapter(
                    child: _LoadFailedBar(
                      onRetry: () => context.read<GalleryCubit>().load(),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.only(top: _gap, bottom: 24),
                  sliver: SliverGrid.builder(
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: _gap,
                          crossAxisSpacing: _gap,
                          childAspectRatio: tileAspect,
                        ),
                    itemBuilder: (context, i) => switch (items[i]) {
                      final GalleryUpload upload => GalleryUploadTile(
                        key: ValueKey(upload.id),
                        upload: upload,
                      ),
                      final photo as GalleryPhoto => GalleryTile(
                        key: ValueKey(photo.id),
                        photo: photo,
                        onTap: () => onOpen(photo),
                        onLongPress: () => onOptions(photo),
                      ),
                    },
                  ),
                ),
              ],
            );
        }
      },
    );
  }
}

/// Above the uploads when the rest of the gallery failed to load.
class _LoadFailedBar extends StatelessWidget {
  const _LoadFailedBar({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Could not load the rest of your gallery.',
              style: TextStyle(fontSize: 13, color: ProfileTokens.muted),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// One tile of the grid. Pinned photos carry a Pinned tag top-left; hidden
/// ones are dimmed with an eye-off mark, so the owner can tell at a glance
/// what visitors will not see (meaning is in the mark, not only the dim).
class GalleryTile extends StatelessWidget {
  const GalleryTile({
    super.key,
    required this.photo,
    required this.onTap,
    this.onLongPress,
  });

  final GalleryPhoto photo;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final drink = photo.drinkName;
    final label = [
      drink ?? 'Photo',
      'at ${photo.cafeName}',
      if (photo.isPinned) 'pinned',
      if (photo.isHidden) 'hidden from your profile',
      if (photo.isModerated) 'removed by Nook, visitors can’t see it',
    ].join(', ');

    return Semantics(
      button: true,
      label: label,
      onLongPressHint: 'Photo options',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: photo.isHidden || photo.isModerated ? 0.4 : 1,
              child: GalleryImage(url: photo.imageUrl, cacheWidth: 360),
            ),
            // Taken down by moderation: not a Cup and can't be pinned, so
            // the owner is told why the counts and the grid disagree.
            if (photo.isModerated)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ModeratedBar(),
              ),
            if (photo.isPinned)
              const Positioned(top: 6, left: 6, child: _PinnedTag()),
            if (photo.isHidden)
              const Positioned(
                top: 6,
                right: 6,
                child: _Badge(icon: LucideIcons.eyeOff),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Removed by Nook" along the bottom of a moderated photo's tile.
class _ModeratedBar extends StatelessWidget {
  const _ModeratedBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC0A0F0D),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        'Removed by Nook',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: ProfileTokens.text(
          11,
          weight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// A photo still on its way in: the picked image, dimmed, with a progress
/// bar; or, when it failed, "Didn't upload" and Retry in its place (Figma
/// E2; Savee's uploading tile, launch-review/profile-ux.md).
class GalleryUploadTile extends StatelessWidget {
  const GalleryUploadTile({super.key, required this.upload});

  final GalleryUpload upload;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GalleryCubit>();
    final failed = upload.failed;
    return Semantics(
      container: true,
      label: failed ? 'Photo didn’t upload' : 'Uploading photo',
      liveRegion: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: failed ? 1 : 0.6,
            child: GalleryImage(url: upload.photo.file.path, cacheWidth: 360),
          ),
          if (!failed)
            const Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(2)),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: Colors.white,
                  backgroundColor: Color(0x66FFFFFF),
                ),
              ),
            )
          else ...[
            const ColoredBox(color: Color(0x990A0F0D)),
            // Scales down rather than clip in a narrow tile at large text.
            Padding(
              padding: const EdgeInsets.all(8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.circleAlert,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Didn’t upload',
                      textAlign: TextAlign.center,
                      style: ProfileTokens.text(
                        12,
                        weight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      button: true,
                      label: 'Retry upload',
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => cubit.retryUpload(upload.id),
                        // 44 tall to the touch; the pill inside is 28.
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Retry',
                              style: ProfileTokens.text(
                                12,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Semantics(
                button: true,
                label: 'Remove this photo',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => cubit.discardUpload(upload.id),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: _Badge(icon: LucideIcons.x),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PinnedTag extends StatelessWidget {
  const _PinnedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: ProfileTokens.brand,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Pinned',
        style: ProfileTokens.text(
          10,
          weight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xB30A0F0D),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 13, color: Colors.white),
    );
  }
}

/// Three dashed slots and one action. Says what belongs here, and that two
/// of the three ways in fill it without trying.
class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        24,
        ProfileTokens.gutter,
        32,
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        onTap: onAdd,
                        child: CustomPaint(
                          painter: _DashedBox(color: ProfileTokens.starEmpty),
                          child: Center(
                            child: Icon(
                              i == 0 ? LucideIcons.plus : LucideIcons.coffee,
                              size: 20,
                              color: i == 0
                                  ? ProfileTokens.brand
                                  : ProfileTokens.starEmpty,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Your coffee, cup by cup',
            textAlign: TextAlign.center,
            style: ProfileTokens.text(16, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Add photos of what you drink, each with its cafe. Photos in '
            'your reviews show up here too, and you can add one each time '
            'you rank a cafe.',
            textAlign: TextAlign.center,
            style: ProfileTokens.text(14, color: ProfileTokens.muted),
          ),
          const SizedBox(height: 20),
          ProfilePillButton(
            label: 'Add photos',
            onTap: onAdd,
            height: 44,
            expand: false,
            padding: 28,
          ),
        ],
      ),
    );
  }
}

class _DashedBox extends CustomPainter {
  const _DashedBox({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          // The same 12 as the lists' cards.
          const Radius.circular(12),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox oldDelegate) => oldDelegate.color != color;
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading your gallery',
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: ProfileGalleryTab._gap),
        crossAxisCount: 3,
        mainAxisSpacing: ProfileGalleryTab._gap,
        crossAxisSpacing: ProfileGalleryTab._gap,
        childAspectRatio: ProfileGalleryTab.tileAspect,
        children: [
          for (var i = 0; i < 9; i++)
            const ProfileSkeleton(height: double.infinity, radius: 0),
        ],
      ),
    );
  }
}
