import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/responsive_card_sizes.dart';
import 'package:nook/features/home_page/presentation/widgets/home_cafe_card.dart';
import 'package:nook/core/widgets/error/section_empty_widget.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/widgets/prototype_height.dart';

class HomeCafeSection extends StatelessWidget {
  final String title;
  final List<CafeSummary> cafes;
  final bool isSkeleton;
  final String? emptySubtitle;

  const HomeCafeSection({
    super.key,
    required this.title,
    required this.cafes,
    this.isSkeleton = false,
    this.emptySubtitle,
  });

  @override
  Widget build(BuildContext context) {
    // Dummy cafe for the prototype — same shape as real data
    const prototypeCafe = CafeSummary(
      id: '',
      name: 'Prototype Cafe Name',
      address: 'Prototype Address',
      rating: 4.9,
      coverImage: null,
      tags: ['Specialty'],
    );

    final double imageHeight = ResponsiveCardSizes.cafeImageHeight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(title, style: context.textTheme.titleMediumSemi),
        ),
        const SizedBox(height: 12),
        if (!isSkeleton && cafes.isEmpty)
          SectionEmptyWidget(
            title: 'No cafes in $title',
            subtitle: emptySubtitle ?? 'Nothing here yet',
            icon: Icons.coffee_outlined,
          )
        else
          PrototypeHeight(
            prototype: HomeCafeCard(cafe: prototypeCafe, height: imageHeight),
            listView: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: cafes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) => HomeCafeCard(
                cafe: cafes[index],
                height: imageHeight,
                isSkeleton: isSkeleton,
              ),
            ),
          ),
      ],
    );
  }
}
