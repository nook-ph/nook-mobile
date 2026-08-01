import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/cafe_open_status.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/presentation/widgets/app_bar_circle_icon_button.dart';
import 'package:nook/core/presentation/widgets/cafe_card_image.dart';
import 'package:nook/core/presentation/widgets/cafe_open_badge.dart';
import 'package:nook/core/presentation/widgets/cafe_rating_label.dart';
import 'package:nook/core/presentation/widgets/cafe_summary_overflow_tags_row.dart';
import 'package:nook/core/extensions/extensions.dart';

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
    final openStatus = CafeOpenStatus.resolve(cafe.operatingHours);
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
                      child: CafeCardImage(imageUrl: imageUrl),
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
                                        style:
                                            context.textTheme.titleMediumSemi,
                                      ),
                                    ),
                                    if (cafe.reviewCount > 0)
                                      const SizedBox(width: 8),
                                    CafeRatingLabel(
                                      rating: cafe.rating,
                                      reviewCount: cafe.reviewCount,
                                      starSize: 14,
                                      starColor: colors.primary100,
                                      ratingStyle:
                                          context.textTheme.bodySmallMed,
                                      countStyle: context.textTheme.bodySmallMed
                                          .copyWith(
                                            color: const Color(0xFF848586),
                                          ),
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
                                        style: context.textTheme.bodySmallMed
                                            .copyWith(
                                              color: const Color(0xFF848586),
                                            ),
                                      ),
                                    ),
                                    // Outside the Expanded so the status always
                                    // fits and the address truncates instead.
                                    if (openStatus.state !=
                                        CafeOpenState.unknown) ...[
                                      const SizedBox(width: 8),
                                      CafeOpenBadge(status: openStatus),
                                    ],
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
