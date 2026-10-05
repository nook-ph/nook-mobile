import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/gallery/domain/entities/gallery_photo.dart';
import 'package:nook/features/gallery/presentation/cubit/gallery_cubit.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_image.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';

/// "12 cups · 7 cafes".
String galleryCountsLine(int cups, int cafes) =>
    '$cups ${cups == 1 ? 'cup' : 'cups'} · '
    '$cafes ${cafes == 1 ? 'cafe' : 'cafes'}';

/// The Gallery tab: a count line with Add photos, then a tight 3-column grid
/// with pinned photos first (TikTok's grid and pin tag; Tinder's dashed
/// empty slots; docs/references/coffee-gallery). Long-press a photo for its
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

  static const _gap = 2.0;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GalleryCubit, GalleryState>(
      builder: (context, state) {
        switch (state.status) {
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
            if (state.photos.isEmpty) return _Empty(onAdd: onAdd);
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(state: state, onAdd: onAdd),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 24),
                  sliver: SliverGrid.builder(
                    itemCount: state.photos.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: _gap,
                          crossAxisSpacing: _gap,
                        ),
                    itemBuilder: (context, i) {
                      final photo = state.photos[i];
                      return GalleryTile(
                        key: ValueKey(photo.id),
                        photo: photo,
                        onTap: () => onOpen(photo),
                        onLongPress: () => onOptions(photo),
                      );
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

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onAdd});

  final GalleryState state;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final hidden = state.hiddenCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        12,
        ProfileTokens.gutter - 8,
        10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: galleryCountsLine(state.cupCount, state.cafeCount),
                    style: ProfileTokens.text(14, weight: FontWeight.w500),
                  ),
                  if (hidden > 0)
                    TextSpan(
                      text: ' · $hidden hidden',
                      style: ProfileTokens.text(14, color: ProfileTokens.muted),
                    ),
                ],
              ),
            ),
          ),
          _AddButton(onTap: onAdd),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add photos',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Padding(
          // 44 tall to the touch; 34 drawn.
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: ProfileTokens.border),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.plus,
                  size: 16,
                  color: ProfileTokens.brand,
                ),
                const SizedBox(width: 4),
                Text(
                  'Add',
                  style: ProfileTokens.text(
                    13,
                    weight: FontWeight.w500,
                    color: ProfileTokens.brand,
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

/// One square of the grid. Pinned photos carry a pin tag top-left; hidden
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
              opacity: photo.isHidden ? 0.4 : 1,
              child: GalleryImage(url: photo.imageUrl, cacheWidth: 360),
            ),
            if (photo.isPinned)
              const Positioned(
                top: 6,
                left: 6,
                child: _Badge(icon: LucideIcons.pin),
              ),
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
        padding: const EdgeInsets.only(top: 52),
        crossAxisCount: 3,
        mainAxisSpacing: ProfileGalleryTab._gap,
        crossAxisSpacing: ProfileGalleryTab._gap,
        children: [
          for (var i = 0; i < 9; i++)
            const ProfileSkeleton(height: double.infinity, radius: 0),
        ],
      ),
    );
  }
}
