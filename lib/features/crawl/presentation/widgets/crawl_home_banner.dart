import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cache/custom_cache_manager.dart';
import 'package:nook/features/crawl/domain/entities/crawl.dart';
import 'package:nook/features/crawl/presentation/cubit/active_crawls_cubit.dart';
import 'package:nook/features/crawl/presentation/cubit/active_crawls_state.dart';

class CrawlHomeBanner extends StatelessWidget {
  const CrawlHomeBanner({
    super.key,
    this.stampProgress,
    this.onJoinCrawl,
  });

  final Map<String, int>? stampProgress;
  final void Function(String crawlSlug)? onJoinCrawl;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActiveCrawlsCubit, ActiveCrawlsState>(
      builder: (context, state) {
        return switch (state) {
          ActiveCrawlsLoaded(:final crawls, :final registeredCrawlIds)
              when crawls.isNotEmpty =>
            _CrawlBannerCard(
              crawl: crawls.first,
              isRegistered: registeredCrawlIds.contains(crawls.first.id),
              stampCount: stampProgress?[crawls.first.id],
              onJoinCrawl: onJoinCrawl,
            ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _CrawlBannerCard extends StatelessWidget {
  const _CrawlBannerCard({
    required this.crawl,
    required this.isRegistered,
    this.stampCount,
    this.onJoinCrawl,
  });

  final Crawl crawl;
  final bool isRegistered;
  final int? stampCount;
  final void Function(String crawlSlug)? onJoinCrawl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _buildBackground(),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${crawl.city.toUpperCase()} ISLAND CRAWL',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Collect stamps. Earn badges.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _FooterItem(
                              icon: LucideIcons.ticket,
                              text:
                                  '${crawl.totalStops} stops across ${crawl.city}',
                            ),
                            const SizedBox(width: 16),
                            _FooterItem(
                              icon: LucideIcons.clock,
                              text: '${crawl.daysRemaining} days left',
                            ),
                            const Spacer(),
                            if (isRegistered)
                              _RegisteredPill(
                                stampCount: stampCount ?? 0,
                                totalStops: crawl.totalStops,
                              )
                            else
                              _JoinButton(
                                onTap: onJoinCrawl != null
                                    ? () => onJoinCrawl!(crawl.slug)
                                    : null,
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
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (crawl.coverImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: crawl.coverImageUrl!,
        cacheManager: CustomCacheManager.instance,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => _buildPlaceholder(),
        placeholder: (_, _) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8E8E8), Color(0xFF9E9E9E)],
        ),
      ),
    );
  }
}

class _FooterItem extends StatelessWidget {
  const _FooterItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisteredPill extends StatelessWidget {
  const _RegisteredPill({
    required this.stampCount,
    required this.totalStops,
  });

  final int stampCount;
  final int totalStops;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF22C55E),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$stampCount / $totalStops stamps',
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: const Text('Join the Crawl'),
    );
  }
}
