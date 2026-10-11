import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cups/domain/entities/cup.dart';
import 'package:nook/features/cups/presentation/cubit/profile_cups_cubit.dart';
import 'package:nook/features/gallery/presentation/widgets/gallery_image.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/profile/presentation/widgets/profile_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A profile's Cups: one tile per cafe, newest visit first, in TikTok's
/// flush 3-column grid; the cafe's name over the bottom of the photo
/// (Google Maps), a stacked-photos mark when there are several
/// (Instagram), the newest stars top-left. A cafe with only notes is a
/// plain tile with the note's first lines (docs/references/cups).
///
/// Reads the [ProfileCupsCubit] above it. The same grid on your own
/// profile and on someone else's.
class ProfileCupsGrid extends StatelessWidget {
  const ProfileCupsGrid({
    super.key,
    required this.onOpen,
    this.onAdd,
    this.isSelf = false,
    this.scrollable = true,
  });

  final ValueChanged<ProfileCafeCups> onOpen;

  /// Your own profile's "Add a cup", for the empty state.
  final VoidCallback? onAdd;
  final bool isSelf;

  /// False inside a parent that scrolls (a sliver list), true in a tab.
  final bool scrollable;

  static const gap = 1.5;
  static const tileAspect = 4 / 5;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCupsCubit, ProfileCupsState>(
      builder: (context, state) {
        final Widget body;
        switch (state.status) {
          case ProfileCupsStatus.initial:
          case ProfileCupsStatus.loading:
            body = const ProfileCupsSkeleton();
          case ProfileCupsStatus.failed:
            body = ProfileMessage.error(
              title: 'Could not load the cups.',
              subtitle: 'Check your connection and try again.',
              actionStyle: ProfilePillStyle.outlined,
              onAction: () => context.read<ProfileCupsCubit>().load(),
            );
          case ProfileCupsStatus.loaded:
            final cups = state.cups;
            if (cups == null || cups.cafes.isEmpty) {
              body = isSelf
                  ? _EmptyOwn(onAdd: onAdd)
                  : const ProfileMessage(
                      icon: LucideIcons.coffee,
                      title: 'No cups yet',
                      subtitle: 'Cups they post at cafes show up here.',
                    );
            } else {
              body = _Grid(cups: cups, onOpen: onOpen);
            }
        }
        if (!scrollable) return body;
        return CustomScrollView(slivers: [SliverToBoxAdapter(child: body)]);
      },
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.cups, required this.onOpen});

  final ProfileCups cups;
  final ValueChanged<ProfileCafeCups> onOpen;

  @override
  Widget build(BuildContext context) {
    String n(int count, String one, String many) =>
        '$count ${count == 1 ? one : many}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            ProfileTokens.gutter,
            10,
            ProfileTokens.gutter,
            8,
          ),
          child: Text(
            [
              n(cups.cupCount, 'cup', 'cups'),
              n(cups.cafeCount, 'cafe', 'cafes'),
              if (cups.photoCount > 0) n(cups.photoCount, 'photo', 'photos'),
            ].join(' · '),
            style: ProfileTokens.text(
              13,
              color: ProfileTokens.muted,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: cups.cafes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: ProfileCupsGrid.gap,
            crossAxisSpacing: ProfileCupsGrid.gap,
            childAspectRatio: ProfileCupsGrid.tileAspect,
          ),
          itemBuilder: (context, i) => ProfileCupTile(
            key: ValueKey(cups.cafes[i].cafeId),
            cafe: cups.cafes[i],
            onTap: () => onOpen(cups.cafes[i]),
          ),
        ),
      ],
    );
  }
}

/// One cafe on the grid.
class ProfileCupTile extends StatelessWidget {
  const ProfileCupTile({super.key, required this.cafe, required this.onTap});

  final ProfileCafeCups cafe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cover = cafe.cover;
    final photos = cafe.photos.length;
    final rating = cafe.rating;
    final visits = cafe.visitCount;
    final meta = visits > 1 ? '$visits visits' : null;
    final label = [
      cafe.cafeName,
      ?meta,
      if (photos > 0) '$photos ${photos == 1 ? 'photo' : 'photos'}',
      if (rating != null) '$rating stars',
      if (cover == null && cafe.note != null) cafe.note!,
    ].join(', ');
    return Semantics(
      button: true,
      label: '$label. Open',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            fit: StackFit.expand,
            children: [
              if (cover != null)
                GalleryImage(
                  url: cover.imageUrl ?? '',
                  cacheWidth: math.max(
                    1,
                    (box.maxWidth * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                  ),
                )
              else
                _NoteTile(note: cafe.note, items: cafe.cups),
              // The name sits on the photo over a scrim, as part of it.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: cover == null
                        ? null
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x000A0F0D), Color(0xB30A0F0D)],
                          ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 18, 8, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (meta != null)
                          Text(
                            meta,
                            maxLines: 1,
                            style: ProfileTokens.text(
                              10.5,
                              color: cover == null
                                  ? ProfileTokens.muted
                                  : const Color(0xE6FFFFFF),
                            ).copyWith(height: 1.3),
                          ),
                        Text(
                          cafe.cafeName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ProfileTokens.text(
                            12,
                            weight: FontWeight.w600,
                            color: cover == null
                                ? ProfileTokens.ink
                                : Colors.white,
                          ).copyWith(height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (rating != null)
                Positioned(top: 6, left: 6, child: _RatingChip(rating: rating)),
              if (photos > 1)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    LucideIcons.layers,
                    size: 16,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x660A0F0D), blurRadius: 4)],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xCC0A0F0D),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            '$rating',
            style: ProfileTokens.text(
              11,
              weight: FontWeight.w600,
              color: Colors.white,
            ).copyWith(height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// A cafe with no photos: its newest note, or what was had there.
class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note, required this.items});

  final String? note;
  final List<CupCard> items;

  @override
  Widget build(BuildContext context) {
    // A note is quoted; what was had is listed as it is.
    final words = note?.trim() ?? '';
    final had = [
      for (final c in items)
        for (final i in c.textItems) i.label!,
    ].join(' · ');
    final text = words.isNotEmpty ? '“$words”' : had;
    return ColoredBox(
      color: const Color(0xFFF1F0EC),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 30, 10, 44),
        child: Text(
          text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: ProfileTokens.text(12, color: ProfileTokens.ink),
        ),
      ),
    );
  }
}

class _EmptyOwn extends StatelessWidget {
  const _EmptyOwn({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final add = onAdd;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        40,
        ProfileTokens.gutter,
        32,
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.coffee, size: 28, color: ProfileTokens.brand),
          const SizedBox(height: 12),
          Text(
            'Your coffee, cup by cup',
            textAlign: TextAlign.center,
            style: ProfileTokens.text(16, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'A cup is one visit: photos of what you had, a note, stars if '
            'you like. Add one from any cafe’s page, or here.',
            textAlign: TextAlign.center,
            style: ProfileTokens.text(14, color: ProfileTokens.muted),
          ),
          if (add != null) ...[
            const SizedBox(height: 20),
            ProfilePillButton(
              label: 'Add a cup',
              onTap: add,
              height: 44,
              expand: false,
              padding: 28,
            ),
          ],
        ],
      ),
    );
  }
}

/// The grid's shape while the cups load.
class ProfileCupsSkeleton extends StatelessWidget {
  const ProfileCupsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading cups',
      child: Skeletonizer.zone(
        effect: const PulseEffect(
          from: ProfileTokens.tint,
          to: Color(0xFFF6F6F6),
        ),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 40),
          crossAxisCount: 3,
          mainAxisSpacing: ProfileCupsGrid.gap,
          crossAxisSpacing: ProfileCupsGrid.gap,
          childAspectRatio: ProfileCupsGrid.tileAspect,
          children: [for (var i = 0; i < 6; i++) const Bone()],
        ),
      ),
    );
  }
}
