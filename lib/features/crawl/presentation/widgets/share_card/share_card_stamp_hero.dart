import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:nook/core/cache/custom_cache_manager.dart';

class ShareCardStampHero extends StatelessWidget {
  final String? cafeLogoUrl;

  const ShareCardStampHero({
    super.key,
    this.cafeLogoUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (cafeLogoUrl == null || cafeLogoUrl!.isEmpty) {
      return const SizedBox.shrink();
    }
    return CircleAvatar(
      radius: 30,
      backgroundImage: CachedNetworkImageProvider(
        cafeLogoUrl!,
        cacheManager: CustomCacheManager.instance,
      ),
    );
  }
}
