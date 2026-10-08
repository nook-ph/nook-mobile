import 'package:flutter/material.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_open_status.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// The top of the details sheet: name, area, and one status line carrying
/// the three facts that decide a visit: rating, open or closed, distance.
class CafeInfoHeader extends StatelessWidget {
  const CafeInfoHeader({super.key, required this.cafe});

  final CafeDetailsResult cafe;

  static String locationText(String neighborhood, String city) => [
    neighborhood,
    city,
  ].map((v) => v.trim()).where((v) => v.isNotEmpty).join(', ');

  @override
  Widget build(BuildContext context) {
    final details = cafe.cafeDetails;
    final textTheme = Theme.of(context).textTheme;
    final location = locationText(details.neighborhood, details.city);
    final status = CafeOpenStatus.resolve(
      details.operatingHours,
      DateTime.now(),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CafeDetailsTokens.gutter),
      child: Column(
        children: [
          // Makes the column as wide as the page so its lines centre on it.
          const SizedBox(width: double.infinity),
          Text(
            details.name,
            textAlign: TextAlign.center,
            style: textTheme.titleLargeSemi.copyWith(
              fontWeight: FontWeight.w600,
              color: CafeDetailsTokens.ink,
            ),
          ),
          if (location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              location,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: CafeDetailsTokens.muted,
              ),
            ),
          ],
          const SizedBox(height: 10),
          CafeDistanceBuilder(
            lat: details.lat,
            lng: details.lng,
            builder: (context, distance) => _StatusLine(
              rating: details.rating,
              reviewCount: details.reviewCount,
              status: status,
              distance: distance,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.rating,
    required this.reviewCount,
    required this.status,
    required this.distance,
  });

  final double rating;
  final int reviewCount;
  final CafeOpenStatus status;
  final String? distance;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final regular = textTheme.bodyLarge?.copyWith(
      color: CafeDetailsTokens.muted,
    );
    final strong = textTheme.bodyLargeMed.copyWith(
      fontWeight: FontWeight.w600,
      color: CafeDetailsTokens.ink,
    );
    final detail = status.shortDetail;

    final parts = <Widget>[
      // A catalog this young means most cafes have no reviews, and "0.0"
      // beside a star reads as a bad cafe rather than a new one.
      if (reviewCount == 0)
        Text(
          'No reviews yet',
          style: strong.copyWith(color: CafeDetailsTokens.muted),
        )
      else
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              PhosphorIconsFill.star,
              size: 14,
              color: CafeDetailsTokens.star,
            ),
            const SizedBox(width: 5),
            Text(rating.toStringAsFixed(1), style: strong),
            const SizedBox(width: 5),
            Text('($reviewCount)', style: regular),
          ],
        ),
      // A listing with no hours at all makes no open-or-closed claim.
      if (status.hasAnyHours)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: CafeDetailsTokens.statusDot(status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: strong.copyWith(
                color: CafeDetailsTokens.statusLabel(status),
              ),
            ),
            if (detail != null) ...[
              const SizedBox(width: 5),
              // Flexible: "Closed · opens 7 AM Wednesday" wraps inside the
              // line at large text instead of overflowing it.
              Flexible(child: Text(detail, style: regular)),
            ],
          ],
        ),
      if (distance != null)
        Text(distance!, style: regular?.copyWith(color: CafeDetailsTokens.ink)),
    ];

    // A Wrap, so a long line breaks between facts at large text sizes
    // instead of clipping one of them.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) Text('·', style: regular),
          parts[i],
        ],
      ],
    );
  }
}
