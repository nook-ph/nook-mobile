import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cache/custom_cache_manager.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';

class CrawlHeroHeader extends StatelessWidget {
  final Crawl? crawl;
  final String crawlImageUrl;
  final int? participantCount;

  const CrawlHeroHeader({
    super.key,
    required this.crawl,
    required this.crawlImageUrl,
    this.participantCount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: CachedNetworkImage(
            imageUrl: crawlImageUrl,
            cacheManager: CustomCacheManager.instance,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => _buildPlaceholder(colors),
            placeholder: (_, _) => _buildPlaceholder(colors),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusChip(status: crawl?.status ?? CrawlStatus.active),
                  const SizedBox(width: 8),
                  _CityChip(city: crawl?.city ?? ''),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                crawl?.title ?? '',
                style: textTheme.titleLargeSemi.copyWith(
                  color: colors.primary100,
                ),
              ),
              if (crawl?.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  crawl!.description!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.gray,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              Divider(color: colors.border, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetaItem(
                      icon: LucideIcons.calendar,
                      label: crawl != null
                          ? _formatDateRange(crawl!.startsAt, crawl!.endsAt)
                          : '',
                      color: colors.gray,
                    ),
                  ),
                  Expanded(
                    child: _MetaItem(
                      icon: LucideIcons.clock,
                      label: crawl != null ? _daysLabel(crawl!.daysRemaining) : '',
                      color: colors.gray,
                    ),
                  ),
                  Expanded(
                    child: _MetaItem(
                      icon: LucideIcons.users,
                      label: _formatParticipantCount(
                        participantCount ?? 0,
                      ),
                      color: colors.gray,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(ColorScheme colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.primary20, colors.primary40],
        ),
      ),
    );
  }

  String _formatDateRange(DateTime startsAt, DateTime endsAt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[startsAt.month]} ${startsAt.day}'
        ' \u2013 '
        '${months[endsAt.month]} ${endsAt.day}';
  }

  String _daysLabel(int days) {
    return days == 1 ? '$days day left' : '$days days left';
  }

  String _formatParticipantCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k joined';
    }
    return '$count joined';
  }
}

class _StatusChip extends StatelessWidget {
  final CrawlStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.success,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.name.toUpperCase(),
            style: TextStyle(
              color: colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  final String city;

  const _CityChip({required this.city});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.gray),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.mapPin, size: 14, color: colors.gray),
          const SizedBox(width: 4),
          Text(
            city.toUpperCase(),
            style: TextStyle(
              color: colors.gray,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
