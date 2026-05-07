import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/features/home_page/presentation/widgets/home_cafe_card.dart';
import 'package:nook/core/widgets/error/section_empty_widget.dart';

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
    final double scale = MediaQuery.textScalerOf(context).scale(1.0);

    final emptyCopy = emptySubtitle ?? 'Nothing here yet';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 8),
        if (!isSkeleton && cafes.isEmpty)
          SectionEmptyWidget(
            title: 'No cafes in $title',
            subtitle: emptyCopy,
            icon: Icons.coffee_outlined,
          )
        else
          SizedBox(
            height: 215 * scale,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: cafes.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return HomeCafeCard(cafe: cafes[index], isSkeleton: isSkeleton);
              },
            ),
          ),
      ],
    );
  }
}
