import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';
import 'package:toastification/toastification.dart';

/// [bottomOffset] lifts the toast above a sticky bottom bar (see
/// [CafeActionsBar]) so it never covers the controls it is reporting on.
///
/// Callers pass the bar's measured height. On top of that, toastification's
/// defaultMarginBuilder already adds 12 to every bottom-aligned toast, so when
/// an offset is given the helper adds only 4 of its own — a ~16pt visual gap —
/// instead of the standalone 16 used when the toast sits on the bare screen
/// edge.
void showPrimaryToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
  double bottomOffset = 0,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final bottomMargin = bottomOffset > 0 ? 4 + bottomOffset : 16.0;

  toastification.show(
    context: context,
    alignment: Alignment.bottomCenter,
    autoCloseDuration: duration,
    style: ToastificationStyle.simple,
    margin: EdgeInsets.fromLTRB(12, 16, 12, bottomMargin),
    backgroundColor: colorScheme.primary80,
    foregroundColor: Colors.white,
    borderRadius: BorderRadius.circular(999),
    // 1. ADDED PADDING HERE: Adjust 'vertical' to make the toast taller or shorter
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    title: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
    closeButton: const ToastCloseButton(showType: CloseButtonShowType.always),
  );
}

/// Primary toast with a trailing action (e.g. "Added to Been · Add a note").
/// Tapping the action dismisses the toast first.
void showPrimaryToastWithAction(
  BuildContext context,
  String message, {
  required String actionLabel,
  required VoidCallback onAction,
  Duration duration = const Duration(seconds: 5),
  double bottomOffset = 0,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  toastification.showCustom(
    context: context,
    alignment: Alignment.bottomCenter,
    autoCloseDuration: duration,
    animationDuration: const Duration(milliseconds: 300),
    animationBuilder: (context, animation, alignment, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    builder: (context, holder) {
      // toastification pins every toast to AlignmentDirectional(-1.0, 0) —
      // hard left — inside its fixed 400pt column, and passes loose
      // constraints (toast_builder.dart:56/88). The `alignment` argument above
      // only picks which screen edge the column sits on, not how a toast sits
      // within it. Because this pill uses MainAxisSize.min it hugs its content
      // and that left pin is visible, so re-centre it here. The other toasts
      // in this file fill the full width, which is why only this one drifted.
      final bottomMargin = bottomOffset > 0 ? 4 + bottomOffset : 16.0;
      return Center(
        child: Container(
          margin: EdgeInsets.fromLTRB(12, 16, 12, bottomMargin),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.primary80,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  message,
                  // Two lines: at one line the action label ate enough width
                  // that "Removed from Been — rank deleted." truncated to
                  // "rank delete…", clipping the consequence being undone.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              AdaptiveTextButton(
                onPressed: () {
                  toastification.dismiss(holder);
                  onAction();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

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

  toastification.showCustom(
    context: context,
    alignment: Alignment.bottomCenter,
    autoCloseDuration: const Duration(seconds: 3),
    animationDuration: const Duration(milliseconds: 300),
    animationBuilder: (context, animation, alignment, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    builder: (context, holder) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        // 2. CHANGED PADDING HERE: Switched from .all(12) to .symmetric to easily control height via 'vertical'
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  normalizedThumbnailUrl == null ||
                      normalizedThumbnailUrl.isEmpty
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
              AdaptiveTextButton(
                onPressed: () {
                  toastification.dismiss(holder);
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
                child: Center(
                  child: Text(
                    'Change',
                    style: context.textTheme.bodyLargeMed.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
