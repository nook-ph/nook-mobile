import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class CafeCard extends StatefulWidget {
  final CafeSummary cafe;
  const CafeCard({super.key, required this.cafe});

  @override
  State<CafeCard> createState() => _CafeCardState();
}

class _CafeCardState extends State<CafeCard> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
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
              child: Image.network(
                widget.cafe.coverImage ?? '',
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
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
                        ' • address', // change with ${widget.cafe.address} later
                        style: Theme.of(context).textTheme.bodyMediumEmp
                            .copyWith(
                              color: Theme.of(context).colorScheme.textgray,
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    spacing: 8,
                    children: [
                      ...widget.cafe.tags
                          .take(3)
                          .map(
                            (tag) => Chip(
                              backgroundColor: Colors.white,
                              visualDensity: VisualDensity(
                                horizontal: 0.0,
                                vertical: -4,
                              ),
                              labelPadding: EdgeInsets.symmetric(horizontal: 6),
                              label: Text(
                                tag,
                                style: Theme.of(context).textTheme.bodySmallEmp
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.black,
                                    ),
                              ),
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.border,
                                ),
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      Spacer(),
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
