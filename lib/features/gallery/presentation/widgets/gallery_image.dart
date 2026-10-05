import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/profile/presentation/widgets/profile_tokens.dart';

/// A gallery photo filling its box. Network images go through the cache;
/// a plain path is a local file (the debug fake, and photos just picked).
class GalleryImage extends StatelessWidget {
  const GalleryImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.dark = false,
    this.cacheWidth,
  });

  final String url;
  final BoxFit fit;

  /// On the viewer's dark ground the placeholders are dark too.
  final bool dark;

  /// Decode size for grid tiles, so a 3-column grid of full-size photos does
  /// not decode 4000 px images.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final fill = dark ? const Color(0xFF1C1F1D) : ProfileTokens.tint;
    final glyph = dark ? const Color(0xFF8E918F) : ProfileTokens.muted;
    Widget placeholder({bool failed = false}) => ColoredBox(
      color: fill,
      child: Center(
        child: Icon(
          failed ? LucideIcons.imageOff : LucideIcons.coffee,
          size: 22,
          color: glyph,
          semanticLabel: failed ? 'Photo could not load' : null,
        ),
      ),
    );

    if (!url.startsWith('http')) {
      return Image.file(
        File(url),
        fit: fit,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => placeholder(failed: true),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => placeholder(),
      errorWidget: (_, _, _) => placeholder(failed: true),
    );
  }
}
