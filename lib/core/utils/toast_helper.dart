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

/// Primary toast with a trailing action (e.g. "Added to Been · Add a note"),
/// and optionally a second one before it ("Undo" · "View"). Tapping an
/// action dismisses the toast first.
///
/// [duration] null keeps the toast until it is acted on, closed (a close
/// button is then shown) or replaced: see [toastDurationFor].
void showPrimaryToastWithAction(
  BuildContext context,
  String message, {
  required String actionLabel,
  required VoidCallback onAction,
  String? secondaryActionLabel,
  VoidCallback? onSecondaryAction,
  Duration? duration = const Duration(seconds: 5),
  double bottomOffset = 0,
}) {
  _showToastBar(
    context,
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    secondaryActionLabel: secondaryActionLabel,
    onSecondaryAction: onSecondaryAction,
    // Every toast with an action, whatever its caller passed, waits for a
    // screen-reader user to reach it.
    duration: duration == null ? null : toastDurationFor(context, duration),
    bottomOffset: bottomOffset,
  );
}

/// [duration], or null (no timeout) when a screen reader or switch access
/// is on: a toast with an action must not vanish before it can be reached
/// (WCAG 2.2.1).
Duration? toastDurationFor(BuildContext context, Duration duration) =>
    MediaQuery.maybeAccessibleNavigationOf(context) ?? false ? null : duration;

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
  String? secondaryActionLabel,
  VoidCallback? onSecondaryAction,
  required Duration? duration,
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
    overlayState: _overlayFor(context),
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
      final hasAction = actionLabel != null;
      final persistent = duration == null;
      final largeText = MediaQuery.textScalerOf(context).scale(14) / 14 > 1.3;
      Widget action(String label, VoidCallback? onTap) => AdaptiveTextButton(
        onPressed: () {
          toastification.dismiss(holder);
          onTap?.call();
        },
        style: TextButton.styleFrom(
          foregroundColor: _toastAction,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          // 48: the touch floor, also for the toast's own actions.
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          style: style?.copyWith(
            color: _toastAction,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      return Container(
        width: double.infinity,
        margin: EdgeInsets.fromLTRB(20, 16, 20, bottomMargin),
        // With actions the 48 targets set the height; the padding shrinks
        // so the bar stays about as tall as a plain one.
        padding: hasAction || persistent
            ? const EdgeInsets.fromLTRB(16, 4, 4, 4)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: _toastInk,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: hasAction || persistent ? 9 : 0,
                ),
                // Its own node, announced when it appears: merged into the
                // close button it was read as one "…, Close" label (N1).
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  child: Text(
                    message,
                    // Two lines, so a long message keeps the part that says
                    // what was lost ("Rank deleted.") instead of truncating
                    // it; three at large text, beside the actions (N8).
                    maxLines: largeText ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: style,
                  ),
                ),
              ),
            ),
            if (secondaryActionLabel != null) ...[
              const SizedBox(width: 4),
              action(secondaryActionLabel, onSecondaryAction),
            ],
            if (hasAction) ...[
              SizedBox(width: secondaryActionLabel != null ? 0 : 4),
              action(actionLabel, onAction),
            ],
            // A toast that does not time out can always be closed.
            if (persistent)
              Semantics(
                // Its own node, so TalkBack's focus is the 48dp button,
                // not the whole bar.
                container: true,
                button: true,
                label: 'Close',
                // The action lives on this node: excluding the children
                // also drops the detector's tap (N1).
                onTap: () => toastification.dismiss(holder),
                excludeSemantics: true,
                // The toast overlay has no Material, so no ink here.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => toastification.dismiss(holder),
                  child: const SizedBox.square(
                    dimension: 48,
                    child: Icon(Icons.close, size: 18, color: _toastText),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// The overlay a toast goes on. A context above the app's navigator (the
/// navigator's own, as app-wide listeners hold) has no overlay over it, so
/// its navigator's overlay is used.
OverlayState? _overlayFor(BuildContext context) {
  final above = context.findAncestorStateOfType<OverlayState>();
  if (above != null) return above;
  if (context is StatefulElement && context.state is NavigatorState) {
    return (context.state as NavigatorState).overlay;
  }
  return null;
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
