import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/map/presentation/widgets/map_open_line.dart';
import 'package:nook/features/search/presentation/widgets/search_tokens.dart';
import 'package:skeletonizer/skeletonizer.dart';

const _fallbackImage =
    'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

String _imageUrl(CafeSummary cafe) {
  final featured = cafe.coverImage?.trim();
  if (featured != null && featured.isNotEmpty) return featured;
  for (final raw in cafe.photoUrls) {
    if (raw.trim().isNotEmpty) return raw.trim();
  }
  return _fallbackImage;
}

/// "350 m" / "1.2 km" from the search's origin; empty when there is none.
String searchDistanceLabel(double? meters) {
  if (meters == null) return '';
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

/// [text] with the first case-insensitive match of [query] in SemiBold, the
/// rest Regular.
List<InlineSpan> highlightSpans(String text, String query, TextStyle base) {
  final q = query.trim().toLowerCase();
  final i = q.isEmpty ? -1 : text.toLowerCase().indexOf(q);
  if (i < 0) return [TextSpan(text: text, style: base)];
  final bold = base.copyWith(fontWeight: FontWeight.w600);
  return [
    if (i > 0) TextSpan(text: text.substring(0, i), style: base),
    TextSpan(text: text.substring(i, i + q.length), style: bold),
    if (i + q.length < text.length)
      TextSpan(text: text.substring(i + q.length), style: base),
  ];
}

class _Photo extends StatelessWidget {
  const _Photo({required this.cafe, required this.size});

  final CafeSummary cafe;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: size,
        child: CafeCardImage(imageUrl: _imageUrl(cafe)),
      ),
    );
  }
}

/// A name match while typing: 48pt photo, name with the typed part bold,
/// area, distance. 72pt tall.
class SearchMatchRow extends StatelessWidget {
  const SearchMatchRow({
    super.key,
    required this.cafe,
    required this.query,
    this.onOpen,
  });

  final CafeSummary cafe;
  final String query;

  /// Called before the cafe opens (the page saves the query as a recent).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final distance = searchDistanceLabel(cafe.distanceMeters);
    return AdaptiveTap(
      onTap: () {
        onOpen?.call();
        context.push('/cafe/${cafe.id}');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _Photo(cafe: cafe, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: highlightSpans(
                        cafe.name,
                        query,
                        SearchTokens.text(context),
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cafe.locationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SearchTokens.text(
                      context,
                      size: 12,
                      color: SearchTokens.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (distance.isNotEmpty) ...[
              const SizedBox(width: 12),
              Text(
                distance,
                style: SearchTokens.text(
                  context,
                  size: 12,
                  color: SearchTokens.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A result: 76pt photo, then name and distance, rating and area, open
/// status, tags. 14pt above and below.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({super.key, required this.cafe});

  final CafeSummary cafe;

  static const int _maxTags = 3;

  @override
  Widget build(BuildContext context) {
    final small = SearchTokens.text(
      context,
      size: 12,
      color: SearchTokens.muted,
    );
    final strong = SearchTokens.text(
      context,
      size: 12,
      weight: FontWeight.w600,
    );
    final open = MapOpenLine.resolve(cafe.operatingHours);
    final tags = cafe.tags.take(_maxTags).join(' · ');
    final distance = searchDistanceLabel(cafe.distanceMeters);
    final rated = cafe.reviewCount > 0;
    // An unrated cafe says so where the star and number would be.
    final countArea = [
      rated ? '(${cafe.reviewCount})' : 'No reviews yet',
      if (cafe.locationLabel.isNotEmpty) cafe.locationLabel,
    ].join(' · ');

    return AdaptiveTap(
      onTap: () => context.push('/cafe/${cafe.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Photo(cafe: cafe, size: 76),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          cafe.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SearchTokens.text(
                            context,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (distance.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          distance,
                          style: SearchTokens.text(context, size: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (rated) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: SearchTokens.star,
                        ),
                        const SizedBox(width: 4),
                        Text(cafe.rating.toStringAsFixed(1), style: strong),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          countArea,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: small,
                        ),
                      ),
                    ],
                  ),
                  if (open != null) ...[
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: open.word,
                            style: strong.copyWith(
                              color: open.isOpen
                                  ? SearchTokens.brand
                                  : SearchTokens.closed,
                            ),
                          ),
                          if (open.detail.isNotEmpty)
                            TextSpan(text: ' · ${open.detail}'),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: small,
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      tags,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: small,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Results while they load: a count bar, then [rows] rows of a 76pt square
/// and four bars, in the shape of [SearchResultRow] without its dividers.
class SearchResultsSkeleton extends StatelessWidget {
  const SearchResultsSkeleton({super.key, this.rows = 5});

  final int rows;

  static const _radius = BorderRadius.all(Radius.circular(6));

  /// Width and height of the name, rating, open-status and tags bars.
  static const _bars = [
    (150.0, 14.0),
    (110.0, 10.0),
    (90.0, 10.0),
    (170.0, 10.0),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading results',
      child: Skeletonizer.zone(
        effect: const PulseEffect(
          from: SearchTokens.field,
          to: Color(0xFFF6F6F6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Bone(width: 110, height: 12, borderRadius: _radius),
            ),
            for (var i = 0; i < rows; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    const Bone.square(
                      size: 76,
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (j, (w, h)) in _bars.indexed) ...[
                            if (j > 0) const SizedBox(height: 10),
                            Bone(width: w, height: h, borderRadius: _radius),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "See all results for “coff”".
class SearchSeeAllRow extends StatelessWidget {
  const SearchSeeAllRow({super.key, required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const Icon(LucideIcons.search, size: 18, color: SearchTokens.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'See all results for “${query.trim()}”',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SearchTokens.text(
                  context,
                  weight: FontWeight.w500,
                  color: SearchTokens.brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A filter suggested by what was typed ("wifi" → Free WiFi): the filter's
/// name and "Filter" in muted text. Tapping applies it in place of the text.
class SearchTagSuggestionRow extends StatelessWidget {
  const SearchTagSuggestionRow({
    super.key,
    required this.tag,
    required this.onTap,
  });

  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            const Icon(
              LucideIcons.slidersHorizontal,
              size: 18,
              color: SearchTokens.brand,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cafes with $tag',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SearchTokens.text(context, weight: FontWeight.w500),
              ),
            ),
            Text(
              'Filter',
              style: SearchTokens.text(
                context,
                size: 12,
                color: SearchTokens.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
