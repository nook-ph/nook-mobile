import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/presentation/widgets/cafe_distance_label.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/geo.dart';
import 'package:nook/features/map/presentation/widgets/map_open_line.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// One cafe in the map's list: photo, then name and distance, rating and
/// area, open status, and tags.
class MapSheetCafeCard extends StatelessWidget {
  const MapSheetCafeCard({
    super.key,
    required this.width,
    required this.cafe,
    this.isSkeleton = false,
    this.showUnratedArea = true,
    this.distanceFrom,
  });

  final double width;
  final CafeSummary cafe;
  final bool isSkeleton;

  /// In the list an unrated cafe reads "No reviews yet · Lahug, Cebu City";
  /// the pin preview card keeps to "No reviews yet".
  final bool showUnratedArea;

  /// Measure the distance from this point (the place chosen to search near)
  /// instead of the phone.
  final GeoPoint? distanceFrom;

  /// The photo is the shortest a row gets; rows with more text lines grow to
  /// fit them instead of reserving a fixed height.
  static const double photoSize = 76;
  static const int _maxTags = 3;

  static const String _fallbackImageUrl =
      'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

  /// Featured image, else first extra photo, else fallback.
  static String _imageUrl(CafeSummary cafe) {
    final featured = cafe.coverImage?.trim();
    if (featured != null && featured.isNotEmpty) return featured;
    for (final raw in cafe.photoUrls) {
      final url = raw.trim();
      if (url.isNotEmpty) return url;
    }
    return _fallbackImageUrl;
  }

  static const noReviews = 'No reviews yet';

  /// "(32) · Lahug, Cebu City"; for an unrated cafe "No reviews yet · Lahug,
  /// Cebu City", or only "No reviews yet" when [withUnratedArea] is false.
  static String countAndArea(CafeSummary cafe, {bool withUnratedArea = true}) {
    final area = cafe.locationLabel;
    if (cafe.reviewCount <= 0) {
      return area.isEmpty || !withUnratedArea
          ? noReviews
          : '$noReviews · $area';
    }
    final count = '(${cafe.reviewCount})';
    return area.isEmpty ? count : '$count · $area';
  }

  /// Distance from [from] to the cafe, or null when it cannot be shown.
  static String? distanceLabel(CafeSummary cafe, GeoPoint from) {
    final lat = cafe.lat;
    final lng = cafe.lng;
    if (lat == null || lng == null) return null;
    return formatDistanceMeters(
      haversineMeters(from, GeoPoint(lat: lat, lng: lng)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final small = textTheme.bodySmall?.copyWith(
      fontSize: 12,
      // Figma: 12pt lines are 18 tall, the 14pt name 21.
      height: 1.5,
      color: MapTokens.muted,
    );
    final strong = small?.copyWith(
      fontWeight: FontWeight.w600,
      color: MapTokens.ink,
    );
    // Skeleton rows carry a placeholder cafe; no status on a shimmer.
    final open = isSkeleton ? null : MapOpenLine.resolve(cafe.operatingHours);
    final tags = cafe.tags.take(_maxTags).join(' · ');
    final rated = cafe.reviewCount > 0;
    final from = distanceFrom;
    final distanceStyle = small?.copyWith(color: MapTokens.ink, height: 1.5);
    final fromPlace = from == null ? null : distanceLabel(cafe, from);

    return SizedBox(
      width: width,
      child: AdaptiveTap(
        onTap: () => context.push('/cafe/${cafe.id}'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox.square(
                dimension: photoSize,
                child: Skeleton.replace(
                  replace: isSkeleton,
                  replacement: const ColoredBox(color: Colors.black),
                  child: CafeCardImage(imageUrl: _imageUrl(cafe)),
                ),
              ),
            ),
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
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                            color: MapTokens.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // From the place being searched near, else from the
                      // device; never from the map camera centre.
                      if (from != null)
                        if (fromPlace != null)
                          Text(fromPlace, style: distanceStyle)
                        else
                          const SizedBox.shrink()
                      else
                        CafeDistanceLabel(
                          lat: cafe.lat,
                          lng: cafe.lng,
                          style: distanceStyle,
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (rated) ...[
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: MapTokens.star,
                        ),
                        const SizedBox(width: 4),
                        Text(cafe.rating.toStringAsFixed(1), style: strong),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          isSkeleton
                              ? cafe.locationLabel
                              : countAndArea(
                                  cafe,
                                  withUnratedArea: showUnratedArea,
                                ),
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
                            style: strong?.copyWith(
                              color: open.isOpen
                                  ? MapTokens.brand
                                  : MapTokens.closed,
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
