import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CafeCard extends StatefulWidget {
  final CafeSummary cafe;
  final bool isSkeleton;

  const CafeCard({
    super.key,
    required this.cafe,
    this.isSkeleton = false,
  });

  @override
  State<CafeCard> createState() => _CafeCardState();
}

class _CafeCardState extends State<CafeCard> {
  static const String _fallbackImageUrl =
      'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.cafe.coverImage?.trim().isNotEmpty == true
        ? widget.cafe.coverImage!.trim()
        : _fallbackImageUrl;

    return AdaptiveTap(
      onTap: () {
        if (widget.isSkeleton) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CafeDetailsPage(cafeId: widget.cafe.id), // change
          ),
        );
      },
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Skeleton.replace(
                replace: widget.isSkeleton,
                replacement: Container(
                  height: 240,
                  width: double.infinity,
                  color: Colors.black,
                ),
                child: Image.network(
                  imageUrl,
                  height: 240,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 16),
            Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 2),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsetsGeometry.only(right: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.cafe.name,
                          style: Theme.of(context).textTheme.titleLargeEmp,
                        ),
                        Icon(PhosphorIconsBold.heart, size: 24),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.cafe.rating.toString(),
                        style: Theme.of(context).textTheme.bodyLargeEmp,
                      ),
                      SizedBox(width: 6),
                      StarRating(rating: widget.cafe.rating),
                      SizedBox(width: 4),
                      Text(
                        '(32)',
                        style: Theme.of(context).textTheme.bodyMediumEmp,
                      ),
                      Text(
                        ' • ${widget.cafe.neighborhood}, ${widget.cafe.city}',
                        style: Theme.of(context).textTheme.bodyMediumEmp
                            .copyWith(
                              color: Theme.of(context).colorScheme.textgray,
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.cafe.tags
                              .take(3)
                              .map(
                                (tag) => Chip(
                                  backgroundColor: Colors.white,
                                  visualDensity: VisualDensity(
                                    horizontal: 0.0,
                                    vertical: -4,
                                  ),
                                  labelPadding:
                                      EdgeInsets.symmetric(horizontal: 6),
                                  label: Text(
                                    tag,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmallEmp.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.black,
                                        ),
                                  ),
                                  shape: StadiumBorder(
                                    side: BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.border,
                                    ),
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.cafe.distanceMeters.toString(),
                        style: Theme.of(context).textTheme.bodySmallEmp
                            .copyWith(
                              color: Theme.of(context).colorScheme.textgray,
                            ),
                      ),
                    ],
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

class StarRating extends StatelessWidget {
  final double rating;
  final double size = 16;

  const StarRating({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    final percentage = (rating / 5).clamp(0.0, 1.0);
    const maxStars = 5;

    return SizedBox(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              spacing: 2,
              children: List.generate(
                maxStars,
                (_) => Icon(
                  PhosphorIconsFill.star,
                  size: size,
                  color: Colors.grey,
                ),
              ),
            ),
          ),

          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Row(
                spacing: 2,
                children: List.generate(
                  maxStars,
                  (_) => Icon(
                    PhosphorIconsFill.star,
                    size: size,
                    color: Theme.of(context).colorScheme.primary100,
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
