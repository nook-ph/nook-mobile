import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nook/core/analytics/home_widget_events.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/home_widget/data/home_widget_platform.dart';
import 'package:nook/features/home_widget/data/widget_promo_store.dart';
import 'package:nook/features/home_widget/domain/saved_cafes_widget_data.dart';
import 'package:nook/features/home_widget/domain/widget_promo_rules.dart';
import 'package:nook/features/home_widget/presentation/saved_cafes_widget_sync.dart';
import 'package:nook/features/lists/presentation/widgets/list_tokens.dart';
import 'package:nook/utils/theme/custom_themes/color_scheme.dart';

/// The Saved tab's one-time "Add widget" card. Shown after three Want to
/// try cafes, or once to someone with Nook's notifications off; at most
/// twice per phone, 14+ days apart ([WidgetPromoRules]). Nothing when it
/// should not show, so a page can always place it.
///
/// "Add widget" asks the launcher to place the widget
/// (`AppWidgetManager.requestPinAppWidget`); the launcher shows its own
/// dialog.
class HomeWidgetPromo extends StatefulWidget {
  const HomeWidgetPromo({
    super.key,
    this.padding = const EdgeInsets.only(top: 24),
    this.platform = const HomeWidgetPluginPlatform(),
    this.store,
    this.feed,
    this.now,
  });

  /// Around the card when it shows; none when it does not.
  final EdgeInsets padding;
  final HomeWidgetPlatform platform;
  final WidgetPromoStore? store;

  /// The widget's Want to try cafes; defaults to [savedCafesWidgetFeed].
  final ValueListenable<List<WidgetCafe>?>? feed;
  final DateTime Function()? now;

  static const savesTitle = 'See your saved cafes on your home screen';
  static const savesBody = 'Which ones are open now, without opening Nook.';
  static const noNotificationsTitle = 'Prefer no notifications? Add the widget';
  static const noNotificationsBody =
      'Your saved cafes and when they open, on your home screen.';
  static const addLabel = 'Add widget';
  static const dismissLabel = 'Not now';

  /// Decided once per app run: the card stays put while the Saved tab is
  /// rebuilt, and a show is counted once.
  static WidgetPromoReason? _sessionReason;
  static bool _sessionClosed = false;

  @visibleForTesting
  static void resetSession() {
    _sessionReason = null;
    _sessionClosed = false;
  }

  @override
  State<HomeWidgetPromo> createState() => _HomeWidgetPromoState();
}

class _HomeWidgetPromoState extends State<HomeWidgetPromo> {
  bool _deciding = false;

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
    _feed.addListener(_onFeed);
    _onFeed();
  }

  @override
  void dispose() {
    _feed.removeListener(_onFeed);
    super.dispose();
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
    if (_deciding || cafes == null || !widget.platform.isSupported) return;
    _deciding = true;
    try {
      final history = await _store.read();
      final notifications = await widget.platform.notificationsEnabled();
      final canPin = await widget.platform.canPin();
      final installed = await widget.platform.installedCount();
      final now = _now();
      final reason = WidgetPromoRules.decide(
        history: history,
        wantToTryCount: cafes.length,
        notificationsOff: notifications == null ? null : !notifications,
        canPin: canPin,
        installedCount: installed,
        now: now,
      );
      if (reason == null || HomeWidgetPromo._sessionReason != null) return;
      final shown = WidgetPromoRules.afterShown(history, reason, now);
      await _store.write(shown);
      HomeWidgetPromo._sessionReason = reason;
      logAppEvent(
        HomeWidgetEvents.promoShown,
        properties: {'reason': _reasonWire, 'show': shown.shownCount},
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[HomeWidgetPromo] decide failed: $e');
    } finally {
      _deciding = false;
    }
  }

  Future<void> _add() async {
    logAppEvent(
      HomeWidgetEvents.promoAdded,
      properties: {'reason': _reasonWire},
    );
    setState(() => HomeWidgetPromo._sessionClosed = true);
    try {
      await _store.markAdded();
      await widget.platform.requestPin();
    } catch (e) {
      debugPrint('[HomeWidgetPromo] pin failed: $e');
    }
  }

  void _dismiss() {
    logAppEvent(
      HomeWidgetEvents.promoDismissed,
      properties: {'reason': _reasonWire},
    );
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
      child: HomeWidgetPromoCard(
        title: noNotifications
            ? HomeWidgetPromo.noNotificationsTitle
            : HomeWidgetPromo.savesTitle,
        body: noNotifications
            ? HomeWidgetPromo.noNotificationsBody
            : HomeWidgetPromo.savesBody,
        preview: SavedCafesWidgetData.frameAt(_feed.value ?? const [], _now()),
        names: {
          for (final c in _feed.value ?? const <WidgetCafe>[]) c.id: c.name,
        },
        onAdd: _add,
        onDismiss: _dismiss,
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
          Row(
            children: [
              Expanded(
                child: _PromoButton(
                  label: HomeWidgetPromo.dismissLabel,
                  filled: false,
                  onTap: onDismiss,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PromoButton(
                  label: HomeWidgetPromo.addLabel,
                  filled: true,
                  onTap: onAdd,
                ),
              ),
            ],
          ),
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
          constraints: const BoxConstraints(minHeight: 44),
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
