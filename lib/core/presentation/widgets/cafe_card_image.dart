import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nook/core/cache/custom_cache_manager.dart';

class CafeCardImage extends StatelessWidget {
  const CafeCardImage({
    super.key,
    required this.imageUrl,
    required this.height,
    required this.width,
  });

  final String imageUrl;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        cacheManager: CustomCacheManager.instance,
        fit: BoxFit.cover,
        // A neutral block, not nothing: an empty placeholder leaves a
        // card-shaped hole in the layout while the image loads. On the ranking
        // comparison sheet that meant one of two cafes rendered and the other
        // did not, which biases the choice the whole feature is built on.
        placeholder: (_, _) => const ColoredBox(color: Color(0xFFE5E7EB)),
        errorWidget: (_, _, _) => Container(
          color: const Color(0xFFE5E7EB),
          alignment: Alignment.center,
          child: const Icon(
            Icons.coffee_outlined,
            color: Color(0xFF6B7280),
            size: 32,
          ),
        ),
      ),
    );
  }
}
