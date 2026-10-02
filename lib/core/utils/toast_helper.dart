import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:toastification/toastification.dart';

/// The app's toast: one dark bar across the bottom, message on the left and
/// an optional action on the right.
///
/// Only one is ever on screen. A new toast replaces the one showing, so a
/// quick run of taps (Been, then Want to Try, then Been again) reports the
/// last thing that happened and nothing stacks up the screen.
///
/// [bottomOffset] lifts the toast above a sticky bottom bar (see
/// [CafeActionsBar]) so it never covers the controls it is reporting on.
/// Callers pass the bar's measured height. toastification's
/// defaultMarginBuilder already adds 12 below every bottom-aligned toast, so
/// with an offset that 12 is the whole gap above the bar; on a bare screen
/// edge the helper adds 4 more.
void showPrimaryToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 3),
  double bottomOffset = 0,
}) {
  _showToastBar(
    context,
    message,
    duration: duration,
    bottomOffset: bottomOffset,
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
  _showToastBar(
    context,
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
    bottomOffset: bottomOffset,
  );
}

/// Removes whatever toast is showing. Call before opening a sheet or leaving
/// a page, so a toast about the previous step does not sit on top of the next.
void dismissToasts() => toastification.dismissAll(delayForAnimation: false);

const _toastInk = Color(0xFF0A0F0D);
const _toastText = Color(0xFFFEFEFE);

void _showToastBar(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  required Duration duration,
  required double bottomOffset,
}) {
  dismissToasts();

  // The measured bar already includes the bottom safe-area inset, and the
  // toast overlay adds that inset again, so take one back. Read from the
  // caller's context: inside the overlay the inset is already consumed.
  final inset = MediaQuery.viewPaddingOf(context).bottom;

  toastification.showCustom(
    context: context,
    alignment: Alignment.bottomCenter,
    autoCloseDuration: duration,
    animationDuration: const Duration(milliseconds: 200),
    animationBuilder: (context, animation, alignment, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    builder: (context, holder) {
      final style = Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: _toastText, fontSize: 14);
      final bottomMargin = bottomOffset > 0
          ? (bottomOffset - inset).clamp(0.0, double.infinity)
          : 4.0;
      return Container(
        width: double.infinity,
        margin: EdgeInsets.fromLTRB(20, 16, 20, bottomMargin),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: _toastInk,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                // Two lines, so a long message keeps the part that says what
                // was lost ("Rank deleted.") instead of truncating it.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(width: 12),
              AdaptiveTextButton(
                onPressed: () {
                  toastification.dismiss(holder);
                  onAction?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: _toastText,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: style?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
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
