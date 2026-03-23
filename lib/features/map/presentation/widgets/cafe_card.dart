import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

class CafeCard extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String address;
  final double rating;
  final String tag;
  final String distance;
  final String cafeId;

  const CafeCard({
    super.key,
    this.imageUrl = 'https://picsum.photos/200/300?grayscale',
    this.name = 'Name',
    this.address = '123 Street, City',
    this.rating = 5,
    this.tag = 'Tag',
    this.distance = '5.0 km',
    this.cafeId = 'cafe-101',
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CafeDetailsPage(cafeId: cafeId), // change
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
                imageUrl,
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
                          name,
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
                        rating.toString(),
                        style: Theme.of(context).textTheme.bodyLargeEmp,
                      ),
                      SizedBox(width: 6),
                      StarRating(rating: rating),
                      SizedBox(width: 4),
                      Text(
                        '(32)',
                        style: Theme.of(context).textTheme.bodyMediumEmp,
                      ),
                      Text(
                        ' • $address',
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
                      Chip(
                        backgroundColor: Colors.white,
                        visualDensity: VisualDensity(
                          // removes vertical padding (flutter chips r weird)
                          horizontal: 0.0,
                          vertical: -4,
                        ),
                        labelPadding: EdgeInsets.symmetric(horizontal: 6),
                        label: Text(
                          'Student Friendly',
                          style: Theme.of(context).textTheme.bodySmallEmp
                              .copyWith(
                                color: Theme.of(context).colorScheme.black,
                              ),
                        ),
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.border,
                          ),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        backgroundColor: Colors.white,
                        visualDensity: VisualDensity(
                          // removes vertical padding (flutter chips r weird)
                          horizontal: 0.0,
                          vertical: -4,
                        ),
                        labelPadding: EdgeInsets.symmetric(horizontal: 6),
                        label: Text(
                          'wassuh',
                          style: Theme.of(context).textTheme.bodySmallEmp
                              .copyWith(
                                color: Theme.of(context).colorScheme.black,
                              ),
                        ),
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.border,
                          ),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        backgroundColor: Colors.white,
                        visualDensity: VisualDensity(
                          // removes vertical padding (flutter chips r weird)
                          horizontal: 0.0,
                          vertical: -4,
                        ),
                        labelPadding: EdgeInsets.symmetric(horizontal: 6),
                        label: Text(
                          '...',
                          style: Theme.of(context).textTheme.bodySmallEmp
                              .copyWith(
                                color: Theme.of(context).colorScheme.black,
                              ),
                        ),
                        shape: StadiumBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.border,
                          ),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Spacer(),
                      Text(
                        distance,
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
