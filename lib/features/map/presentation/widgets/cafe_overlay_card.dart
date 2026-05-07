import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/presentation/widgets/app_bar_circle_icon_button.dart';
import 'package:nook/core/presentation/widgets/cafe_summary_overflow_tags_row.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class CafeOverlayCard extends StatelessWidget {
  final CafeSummary cafe;
  final VoidCallback onClose;

  const CafeOverlayCard({super.key, required this.cafe, required this.onClose});

  static const String _fallbackImageUrl =
      'https://images.unsplash.com/photo-1497935586351-b67a49e012bf';

  static const double _cardHeight = 320;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final String imageUrl = cafe.coverImage?.trim().isNotEmpty == true
        ? cafe.coverImage!.trim()
        : _fallbackImageUrl;

    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: _cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              AdaptiveTap(
                onTap: () => context.push('/cafe/${cafe.id}'),
                child: Column(
                  children: [
                    Expanded(
                      flex: 19,
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Expanded(
                      flex: 11,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cafe.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          PhosphorIconsFill.star,
                                          size: 14,
                                          color: colors.primary100,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          cafe.rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '(${cafe.reviewCount})',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF848586),
                                          ),
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
                                        cafe.locationLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF848586),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            CafeSummaryOverflowTagsRow(tags: cafe.tags),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: AppBarCircleIconButton(
                  icon: Icons.close,
                  iconSize: 14,
                  dimension: 32,
                  onTap: onClose,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
