import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nook/core/cache/custom_cache_manager.dart';

/// The one way this app draws a cafe photo.
///
/// Every surface must go through here rather than `Image.network`, which has
/// no disk cache (so a photo is re-downloaded on every tab switch — real money
/// on mobile data) and paints nothing while loading (so cards appear as blank
/// holes on the discovery surfaces).
///
/// [height] and [width] default to filling the parent, for the cards that size
/// their image with `Expanded` rather than a fixed box.
///
/// The photo is decoded at the size it is drawn, not the size it was
/// uploaded: a 1280 px photo in a 76 pt thumbnail would otherwise hold 5 MB of
/// pixels to show a few thousand of them.
class CafeCardImage extends StatelessWidget {
  const CafeCardImage({
    super.key,
    required this.imageUrl,
    this.height = double.infinity,
    this.width = double.infinity,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final double height;
  final double width;

  /// Shown while the photo loads. Defaults to a neutral grey block.
  final Widget? placeholder;

  /// Shown when the photo cannot be loaded. Defaults to a coffee icon on grey.
  final Widget? errorWidget;

  /// The decode width, in physical pixels, for a box of [size] logical
  /// pixels, or null when the box has no finite size to go by.
  ///
  /// Only the width is constrained, so the photo keeps its shape. The photo
  /// is drawn with [BoxFit.cover], and a landscape photo in a square or tall
  /// box has to cover the height, so the box's height counts too, with room
  /// for photos up to 3:2. Rounded up to a step of 100 so boxes a few pixels
  /// apart share one decoded image.
  static int? decodeWidth(Size size, double devicePixelRatio) {
    if (!size.width.isFinite || !size.height.isFinite) return null;
    final logical = size.width > size.height * 1.5
        ? size.width
        : size.height * 1.5;
    if (logical <= 0) return null;
    return ((logical * devicePixelRatio) / 100).ceil() * 100;
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      height: height,
      width: width,
      child: LayoutBuilder(
        builder: (context, constraints) => CachedNetworkImage(
          imageUrl: imageUrl,
          cacheManager: CustomCacheManager.instance,
          fit: BoxFit.cover,
          width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
          height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
          memCacheWidth: decodeWidth(constraints.biggest, devicePixelRatio),
          // A neutral block, not nothing: an empty placeholder leaves a
          // card-shaped hole in the layout while the image loads. On the
          // ranking comparison sheet that meant one of two cafes rendered and
          // the other did not, which biases the choice the whole feature is
          // built on.
          placeholder: (_, _) =>
              placeholder ?? const ColoredBox(color: Color(0xFFE5E7EB)),
          errorWidget: (_, _, _) =>
              errorWidget ??
              Container(
                color: const Color(0xFFE5E7EB),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.coffee_outlined,
                  color: Color(0xFF6B7280),
                  size: 32,
                ),
              ),
        ),
      ),
    );
  }
}
