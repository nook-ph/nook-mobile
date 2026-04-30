import 'package:another_flushbar/flushbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

void showSavedToListToast(
  BuildContext context,
  String cafeName,
  String? thumbnailUrl, {
  required String listDisplayName,
  VoidCallback? onChange,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final normalizedThumbnailUrl = thumbnailUrl?.trim();
  final trimmedListTitle = listDisplayName.trim();
  final mutedLine = trimmedListTitle.isEmpty
      ? 'Saved to recent list'
      : 'Saved to recent list $trimmedListTitle';
  late final Flushbar<void> flushbar;

  flushbar = Flushbar<void>(
    flushbarStyle: FlushbarStyle.FLOATING,
    flushbarPosition: FlushbarPosition.BOTTOM,
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    borderRadius: BorderRadius.circular(12),
    backgroundColor: Colors.white,
    duration: const Duration(seconds: 3),
    animationDuration: const Duration(milliseconds: 300),
    forwardAnimationCurve: Curves.easeOut,
    dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    boxShadows: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.18),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
    messageText: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child:
              normalizedThumbnailUrl == null || normalizedThumbnailUrl.isEmpty
              ? Container(
                  width: 48,
                  height: 48,
                  color: colorScheme.surfaceContainerHighest,
                )
              : CachedNetworkImage(
                  imageUrl: normalizedThumbnailUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    width: 48,
                    height: 48,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  placeholder: (_, _) => Container(
                    width: 48,
                    height: 48,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mutedLine,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                cafeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        if (onChange == null)
          const Icon(Icons.bookmark, color: Colors.amber, size: 22)
        else
          TextButton(
            onPressed: () {
              flushbar.dismiss();
              onChange();
            },
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF33523F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Change',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    ),
  );

  flushbar.show(context);
}
