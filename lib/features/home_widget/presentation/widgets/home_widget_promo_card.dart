import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nook/core/analytics/home_widget_events.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/home_widget/data/home_widget_platform.dart';
import 'package:nook/features/home_widget/data/widget_promo_store.dart';
import 'package:nook/features/home_widget/domain/notification_decline.dart';
import 'package:nook/features/home_widget/domain/saved_cafes_widget_data.dart';
import 'package:nook/features/home_widget/domain/widget_promo_rules.dart';
import 'package:nook/features/home_widget/presentation/saved_cafes_widget_sync.dart';
import 'package:nook/features/home_widget/presentation/widgets/on_screen_detector.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

/// The Saved tab's one-time "Add widget" card. Shown after three Want to
/// try cafes, or once to someone who really declined Nook's notifications
/// ([NotificationsState]); at most twice per phone, 14+ days apart
/// ([WidgetPromoRules]). Nothing when it should not show, so a page can
/// always place it.
///
/// A show is spent only when the card has actually been seen (half of it on
/// screen for a second, [OnScreenDetector]). "Add widget" asks the launcher
/// to place the widget (`AppWidgetManager.requestPinAppWidget`); the
/// launcher shows its own dialog, and on the next resume the widget count
/// says whether it was added. Only then is the card retired, with a toast
/// saying where to look; a Cancel keeps the remaining show.
class HomeWidgetPromo extends StatefulWidget {
  const HomeWidgetPromo({
    super.key,
    this.padding = const EdgeInsets.only(top: 24),
    this.platform = const HomeWidgetPluginPlatform(),
    this.store,
    this.feed,
    this.now,
    this.declines = const UnknownNotificationDecline(),
    this.dwell = const Duration(seconds: 1),
    this.pinSettle = const Duration(milliseconds: 1500),
  });

  /// Around the card when it shows; none when it does not.
  final EdgeInsets padding;
  final HomeWidgetPlatform platform;
  final WidgetPromoStore? store;

  /// The widget's Want to try cafes; defaults to [savedCafesWidgetFeed].
  final ValueListenable<List<WidgetCafe>?>? feed;
  final DateTime Function()? now;

  /// A recorded answer to Nook's own notification ask. Unknown until
  /// `retention/local-notifications` merges (see [NotificationDeclineSource]).
  final NotificationDeclineSource declines;

  /// How long the card must stay on screen to count as seen.
  final Duration dwell;

  /// A launcher can report the new widget a moment after its dialog
  /// closes; the count is read again after this before calling it a cancel.
  final Duration pinSettle;

  static const savesTitle = 'See your saved cafes on your home screen';
  static const savesBody =
      'Your saved cafes and when they open, without opening Nook.';
  static const noNotificationsTitle = 'Prefer no notifications? Add the widget';
  static const noNotificationsBody =
      'Your saved cafes and when they open, on your home screen.';
  static const addLabel = 'Add widget';
  static const dismissLabel = 'Not now';
  static const addedMessage =
      'Widget added. Look for “Your saved cafes” on your home screen.';

  /// Decided once per app run: the card stays put while the Saved tab is
  /// rebuilt, and a show is counted once.
  static WidgetPromoReason? _sessionReason;
  static NotificationsState _sessionNotifications = NotificationsState.unknown;
  static bool _sessionCounted = false;
  static bool _sessionClosed = false;
  static bool _resolvingPin = false;

  @visibleForTesting
  static void resetSession() {
    _sessionReason = null;
    _sessionNotifications = NotificationsState.unknown;
    _sessionCounted = false;
    _sessionClosed = false;
    _resolvingPin = false;
  }

  @override
  State<HomeWidgetPromo> createState() => _HomeWidgetPromoState();
}

class _HomeWidgetPromoState extends State<HomeWidgetPromo>
    with WidgetsBindingObserver {
  bool _deciding = false;
  bool _decideAgain = false;

  ValueListenable<List<WidgetCafe>?> get _feed =>
      widget.feed ?? savedCafesWidgetFeed;
  WidgetPromoStore get _store => widget.store ?? WidgetPromoStore();
  DateTime _now() => (widget.now ?? DateTime.now)();

  String get _reasonWire =>
      HomeWidgetPromo._sessionReason == WidgetPromoReason.noNotifications
      ? WidgetPromoReasons.noNotifications
      : WidgetPromoReasons.saves;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _feed.addListener(_onFeed);
    _onFeed();
    unawaited(_resolvePin());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _feed.removeListener(_onFeed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_resolvePin());
  }

  /// Until the card has shown this run, a new Want to try (the third, say)
  /// is a reason to look again.
  void _onFeed() {
    if (HomeWidgetPromo._sessionReason != null ||
        HomeWidgetPromo._sessionClosed) {
      if (mounted) setState(() {});
      return;
    }
    unawaited(_decide());
  }

  Future<void> _decide() async {
    final cafes = _feed.value;
    if (cafes == null || !widget.platform.isSupported) return;
    if (_deciding) {
      // The feed changed mid-decision (the third save, say): look again
      // with it once this one is done.
      _decideAgain = true;
      return;
    }
    _deciding = true;
    try {
      final history = await _store.read();
      final notifications = NotificationsState.resolve(
        sdkInt: await widget.platform.sdkInt(),
        enabled: await widget.platform.notificationsEnabled(),
        declinedAfterAsk: await widget.declines.declinedAfterAsk(),
      );
      final canPin = await widget.platform.canPin();
      final installed = await widget.platform.installedCount();
      final reason = WidgetPromoRules.decide(
        history: history,
        wantToTryCount: cafes.length,
        notificationsOff: notifications.off,
        canPin: canPin,
        installedCount: installed,
        now: _now(),
      );
      if (reason == null || HomeWidgetPromo._sessionReason != null) return;
      HomeWidgetPromo._sessionReason = reason;
      HomeWidgetPromo._sessionNotifications = notifications;
      logAppEvent(
        HomeWidgetEvents.promoShown,
        properties: {'reason': _reasonWire, 'show': history.shownCount + 1},
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[HomeWidgetPromo] decide failed: $e');
    } finally {
      _deciding = false;
      if (_decideAgain) {
        _decideAgain = false;
        if (mounted) _onFeed();
      }
    }
  }

  /// The card has been seen: spend the show.
  Future<void> _countShow() async {
    final reason = HomeWidgetPromo._sessionReason;
    if (reason == null || HomeWidgetPromo._sessionCounted) return;
    HomeWidgetPromo._sessionCounted = true;
    try {
      final shown = WidgetPromoRules.afterShown(
        await _store.read(),
        reason,
        _now(),
      );
      await _store.write(shown);
      final declineKind = reason == WidgetPromoReason.noNotifications
          ? HomeWidgetPromo._sessionNotifications.declineKind
          : null;
      logAppEvent(
        HomeWidgetEvents.promoViewed,
        properties: {
          'reason': _reasonWire,
          'show': shown.shownCount,
          'decline_kind': ?declineKind,
        },
      );
    } catch (e) {
      debugPrint('[HomeWidgetPromo] count failed: $e');
    }
  }

  Future<void> _add() async {
    logAppEvent(
      HomeWidgetEvents.promoAdded,
      properties: {'reason': _reasonWire},
    );
    // Tapped before the second was up: it was seen.
    await _countShow();
    if (!mounted) return;
    setState(() => HomeWidgetPromo._sessionClosed = true);
    try {
      await _store.setPendingPin(
        PendingWidgetPin(
          at: _now(),
          reason: _reasonWire,
          countBefore: await widget.platform.installedCount(),
        ),
      );
      await widget.platform.requestPin();
    } catch (e) {
      debugPrint('[HomeWidgetPromo] pin failed: $e');
    }
  }

  /// Back from the launcher's dialog: did the widget count rise?
  Future<void> _resolvePin() async {
    if (HomeWidgetPromo._resolvingPin || !widget.platform.isSupported) return;
    HomeWidgetPromo._resolvingPin = true;
    try {
      final pending = await _store.pendingPin();
      if (pending == null) return;
      var after = await widget.platform.installedCount();
      var result = WidgetPinResult.of(
        before: pending.countBefore,
        after: after,
      );
      if (result != WidgetPinResult.added) {
        await Future<void>.delayed(widget.pinSettle);
        after = await widget.platform.installedCount();
        result = WidgetPinResult.of(before: pending.countBefore, after: after);
      }
      await _store.clearPendingPin();
      // Long after the tap, a new widget may as well be from the launcher's
      // picker: not credited to the card.
      if (!pending.isFresh(_now())) result = WidgetPinResult.unknown;
      logAppEvent(
        HomeWidgetEvents.pinResult,
        properties: {'result': result.name, 'reason': pending.reason},
      );
      if (result != WidgetPinResult.added) return;
      await _store.markAdded();
      if (mounted) {
        showPrimaryToast(
          context,
          HomeWidgetPromo.addedMessage,
          duration: const Duration(seconds: 5),
          bottomOffset: _barHeight(),
        );
      }
    } catch (e) {
      debugPrint('[HomeWidgetPromo] pin result failed: $e');
    } finally {
      HomeWidgetPromo._resolvingPin = false;
    }
  }

  /// What sits under the Saved tab's list (the tab bar), so the toast lands
  /// above it.
  double _barHeight() {
    final box = Scrollable.maybeOf(context)?.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return 0;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    final screen = MediaQuery.sizeOf(context).height;
    return (screen - bottom).clamp(0, screen / 3).toDouble();
  }

  void _dismiss() {
    logAppEvent(
      HomeWidgetEvents.promoDismissed,
      properties: {'reason': _reasonWire},
    );
    unawaited(_countShow());
    setState(() => HomeWidgetPromo._sessionClosed = true);
  }

  @override
  Widget build(BuildContext context) {
    final reason = HomeWidgetPromo._sessionReason;
    if (reason == null || HomeWidgetPromo._sessionClosed) {
      return const SizedBox.shrink();
    }
    final noNotifications = reason == WidgetPromoReason.noNotifications;
    return Padding(
      padding: widget.padding,
      child: OnScreenDetector(
        dwell: widget.dwell,
        onSeen: () => unawaited(_countShow()),
        child: HomeWidgetPromoCard(
          title: noNotifications
              ? HomeWidgetPromo.noNotificationsTitle
              : HomeWidgetPromo.savesTitle,
          body: noNotifications
              ? HomeWidgetPromo.noNotificationsBody
              : HomeWidgetPromo.savesBody,
          preview: SavedCafesWidgetData.frameAt(
            _feed.value ?? const [],
            _now(),
          ),
          names: {
            for (final c in _feed.value ?? const <WidgetCafe>[]) c.id: c.name,
          },
          onAdd: _add,
          onDismiss: _dismiss,
        ),
      ),
    );
  }
}

/// The card itself: words and two buttons on the left, a small picture of
/// the widget with the person's own cafes on the right.
class HomeWidgetPromoCard extends StatelessWidget {
  const HomeWidgetPromoCard({
    super.key,
    required this.title,
    required this.body,
    required this.preview,
    required this.names,
    required this.onAdd,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final WidgetFrame preview;
  final Map<String, String> names;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ListsTokens.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ListsTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: listsText(
                        15,
                        weight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(body, style: listsText(13, color: ListsTokens.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ExcludeSemantics(
                child: _WidgetPreview(frame: preview, names: names),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PromoActions(onAdd: onAdd, onDismiss: onDismiss),
        ],
      ),
    );
  }
}

/// "Not now" and "Add widget" side by side, the same height; stacked full
/// width with "Add widget" on top once large text would wrap them.
class _PromoActions extends StatelessWidget {
  const _PromoActions({required this.onAdd, required this.onDismiss});

  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  /// From here the two labels no longer fit side by side on a phone.
  static const _stackAtScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final add = _PromoButton(
      label: HomeWidgetPromo.addLabel,
      filled: true,
      onTap: onAdd,
    );
    final dismiss = _PromoButton(
      label: HomeWidgetPromo.dismissLabel,
      filled: false,
      onTap: onDismiss,
    );
    if (MediaQuery.textScalerOf(context).scale(1) >= _stackAtScale) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [add, const SizedBox(height: 8), dismiss],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: dismiss),
          const SizedBox(width: 8),
          Expanded(child: add),
        ],
      ),
    );
  }
}

/// A home screen in miniature: the widget's first two rows on a tinted
/// "wallpaper". Decoration only; screen readers skip it.
class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({required this.frame, required this.names});

  final WidgetFrame frame;
  final Map<String, String> names;

  static Color _dot(BuildContext context, WidgetRowTone tone) {
    final scheme = Theme.of(context).colorScheme;
    return switch (tone) {
      WidgetRowTone.open => scheme.success,
      WidgetRowTone.closingSoon => scheme.warning,
      _ => ListsTokens.checkbox,
    };
  }

  @override
  Widget build(BuildContext context) {
    final rows = frame.rows.take(2).toList();
    return Container(
      width: 92,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: ListsTokens.sage,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        decoration: BoxDecoration(
          color: ListsTokens.surface,
          // The outer 12 less its 8 of padding.
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: ListsTokens.brand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            for (final row in rows) ...[
              const SizedBox(height: 7),
              Text(
                names[row.cafeId] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: listsText(10, weight: FontWeight.w500, height: 1.2),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _dot(context, row.tone),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: ListsTokens.tint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PromoButton extends StatelessWidget {
  const _PromoButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? ListsTokens.brand : ListsTokens.surface,
            borderRadius: BorderRadius.circular(100),
            border: filled ? null : Border.all(color: ListsTokens.border),
          ),
          child: Text(
            label,
            style: listsText(
              14,
              weight: FontWeight.w500,
              color: filled ? ListsTokens.surface : ListsTokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}
