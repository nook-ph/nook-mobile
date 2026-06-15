import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';

class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.cafe});

  final CafeSummary cafe;

  @override
  Widget build(BuildContext context) {
    final cardWidth = MediaQuery.of(context).size.width - 44;
    const double radius = 12.0;

    return Container(
      width: cardWidth,
      height: 106,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
        color: Colors.white,
      ),

      clipBehavior: Clip.antiAlias,
      child: AdaptiveTap(
        borderRadius: BorderRadius.circular(radius),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CafeDetailsPage(cafeId: cafe.id),
            ),
          );
        },
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: cafe.coverImage != null && cafe.coverImage!.isNotEmpty
                  ? Image.network(
                      cafe.coverImage!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                cafe.name,
                                style: context.textTheme.titleMediumSemi,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  cafe.rating.toStringAsFixed(1),
                                  style: context.textTheme.bodySmallMed,
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.star,
                                  color: Color(0xFF588157),
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.mapPin500,
                              size: 12,
                              color: Color(0xFF848586),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                cafe.address.isEmpty
                                    ? 'Address unavailable'
                                    : cafe.address,
                                style: context.textTheme.bodySmallMed.copyWith(
                                  color: const Color(0xFF848586),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                ),
                              ),
                              child: Text(
                                cafe.tags.isNotEmpty
                                    ? cafe.tags.first
                                    : 'Student Friendly',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                        ),
                        Text(
                          '5.0 km',
                          style: context.textTheme.bodySmallMed.copyWith(
                            color: const Color(0xFF848685),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildPlaceholder() {
  return Container(
    width: double.infinity,
    height: double.infinity,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE8E8E8), Color(0xFF9E9E9E)],
      ),
    ),
    child: const Icon(LucideIcons.coffee, color: Color(0xFFBDBDBD), size: 28),
  );
}
