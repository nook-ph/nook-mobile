import 'package:flutter/material.dart';
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

/// The action label ("Undo", "Change"): sage on the dark bar.
const _toastAction = Color(0xFFA3B18A);

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
  // view, not the caller's MediaQuery: under a Scaffold with a bottom bar
  // the body's inset is already zeroed, which left the toast a whole
  // home-indicator height too high.
  final view = View.of(context);
  final inset = view.viewPadding.bottom / view.devicePixelRatio;

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
                  foregroundColor: _toastAction,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel,
                  style: style?.copyWith(
                    color: _toastAction,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// "Saved to Favorites · Change", shown when the bookmark on a cafe page
/// quick-saves to the last used list (Figma "Saved toast — proposal", A).
/// It is the same bar as every other toast; [onChange] opens Save to….
void showSavedToListToast(
  BuildContext context, {
  required String listDisplayName,
  required VoidCallback onChange,
  double bottomOffset = 0,
}) {
  showPrimaryToastWithAction(
    context,
    savedToListMessage(listDisplayName),
    actionLabel: 'Change',
    onAction: onChange,
    bottomOffset: bottomOffset,
  );
}

/// "Saved to Favorites", or "Saved" when the list has no name to show.
String savedToListMessage(String listDisplayName) {
  final name = listDisplayName.trim();
  return name.isEmpty ? 'Saved' : 'Saved to $name';
}
