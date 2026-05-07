import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class BookmarkIconButton extends StatelessWidget {
  const BookmarkIconButton({
    super.key,
    required this.isSaved,
    required this.onTap,
    this.isEnabled = true,
    this.showCircleBackground = true,
    this.iconSize = 18,
  });

  final bool isSaved;
  final VoidCallback? onTap;
  final bool isEnabled;
  final bool showCircleBackground;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      PhosphorIcons.bookmarkSimple(
        isSaved ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular,
      ),
      color: isSaved ? const Color(0xFFFFC107) : Colors.black,
      size: iconSize,
    );

    // Handle the disabled state for the callback
    final VoidCallback? handleTap = isEnabled ? onTap : null;

    if (!showCircleBackground) {
      return AdaptiveTap(
        onTap: handleTap ?? () {},
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(8), child: icon),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      child: AdaptiveTap(
        onTap: handleTap ?? () {},
        borderRadius: BorderRadius.circular(20), 
        child: Center(child: icon),
      ),
    );
  }
}
