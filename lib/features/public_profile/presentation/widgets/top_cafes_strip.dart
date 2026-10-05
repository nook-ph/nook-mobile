import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';
import 'package:nook/features/public_profile/domain/entities/public_profile.dart';

/// "Top cafes": the person's three best-liked cafes as three equal photo
/// tiles in rank order, each with a 1/2/3 marker on the photo and the name
/// and area under it. No scores: rankings stay private (RANKING_DESIGN.md
/// §1.1), only the order is shared.
///
/// Structure from Airbuds (three equal tiles, text under the image) and
/// Showcase (the marker inside the photo's top-left corner);
/// docs/references/public-profile. With one or two cafes the tiles keep
/// their width and sit at the left. With none the strip is not built at all
/// (the caller leaves it out).
class TopCafesStrip extends StatelessWidget {
  const TopCafesStrip({super.key, required this.cafes, required this.onOpen});

  final List<PublicTopCafe> cafes;
  final ValueChanged<String> onOpen;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final shown = cafes.take(3).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        4,
        ProfileTokens.gutter,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Top cafes',
              style: ProfileTokens.text(16, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(
                  child: i < shown.length
                      ? _TopCafeTile(
                          cafe: shown[i],
                          onTap: () => onOpen(shown[i].cafeId),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TopCafeTile extends StatelessWidget {
  const _TopCafeTile({required this.cafe, required this.onTap});

  final PublicTopCafe cafe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = cafe.imageUrl;
    final area = cafe.area;
    return Semantics(
      button: true,
      label: [
        'Number ${cafe.rank}',
        cafe.name,
        if (area != null && area.isNotEmpty) area,
      ].join(', '),
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: image == null || image.isEmpty
                        ? const ColoredBox(
                            color: ProfileTokens.tint,
                            child: Icon(
                              LucideIcons.coffee,
                              size: 22,
                              color: ProfileTokens.muted,
                            ),
                          )
                        : CafeCardImage(imageUrl: image),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _RankMarker(rank: cafe.rank),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Two lines: a third of a phone is too narrow for most names.
            Text(
              cafe.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ProfileTokens.text(13, weight: FontWeight.w500),
            ),
            if (area != null && area.isNotEmpty)
              Text(
                area,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ProfileTokens.text(12, color: ProfileTokens.muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// The rank on a white disc, so it reads on any photo.
class _RankMarker extends StatelessWidget {
  const _RankMarker({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: ProfileTokens.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$rank',
        style: ProfileTokens.text(
          12,
          weight: FontWeight.w600,
          color: ProfileTokens.brand,
        ),
      ),
    );
  }
}

/// The strip's shape in grey while the profile loads.
class TopCafesStripSkeleton extends StatelessWidget {
  const TopCafesStripSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ProfileTokens.gutter,
        4,
        ProfileTokens.gutter,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 96,
            height: 16,
            decoration: BoxDecoration(
              color: ProfileTokens.tint,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: TopCafesStrip._gap),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ProfileTokens.tint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
