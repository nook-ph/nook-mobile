import 'package:flutter/material.dart';
import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';
import 'package:nook/features/home_page/presentation/widgets/home_cafe_card.dart';

class HomeCafeSection extends StatelessWidget {
  final String title;
  final List<CafeSummaryEntity> cafes;
  final bool isSkeleton;

  const HomeCafeSection({
    super.key,
    required this.title,
    required this.cafes,
    this.isSkeleton = false,
  });

  @override
  Widget build(BuildContext context) {
    final double scale = MediaQuery.textScalerOf(context).scale(1.0);
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
