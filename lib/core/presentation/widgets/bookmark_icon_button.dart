import 'package:flutter/material.dart';
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

  /// App bar style: white circular chip. When false, only the icon is shown
  /// (e.g. save-to-list sheet row).
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

    if (!showCircleBackground) {
      return GestureDetector(
        onTap: isEnabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(padding: const EdgeInsets.all(8), child: icon),
      );
    }

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Center(child: icon),
      ),
    );
  }
}
