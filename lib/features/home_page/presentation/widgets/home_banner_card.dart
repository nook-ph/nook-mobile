import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/analytics/screen_tracking.dart';
import 'package:nook/core/cache/custom_cache_manager.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/responsive_card_sizes.dart';
import 'package:nook/core/utils/toast_helper.dart';
import 'package:nook/features/home_page/data/home_banner_dismiss_store.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';
import 'package:nook/features/home_page/presentation/home_link.dart';
import 'package:nook/features/home_page/presentation/pages/home_shelf_page.dart';
import 'package:nook/injection_container.dart';

/// The admin banner at the top of Home, with its gap to the first shelf.
/// Renders nothing while outside its schedule, once closed for this
/// version, and until the phone has said whether it was closed (so a
/// dismissed banner never flashes).
class HomeBannerSlot extends StatefulWidget {
  const HomeBannerSlot({
    super.key,
    required this.banner,
    required this.version,
    required this.now,
    this.store,
  });

  final HomeBanner banner;

  /// The published layout's row id.
  final String version;
  final DateTime now;

  /// Defaults to the app's; tests pass their own.
  final HomeBannerDismissStore? store;

  /// Banners already reported as shown in this app run.
  static final Set<String> _shown = {};

  @visibleForTesting
  static void resetForTest() => _shown.clear();

  @override
  State<HomeBannerSlot> createState() => _HomeBannerSlotState();
}

class _HomeBannerSlotState extends State<HomeBannerSlot> {
  Set<String>? _dismissed;
  Set<String> _tapped = const {};

  /// Size changes animate only after a tap here (close, Undo), never on
  /// the first paint.
  bool _animate = false;

  HomeBannerDismissStore get _store =>
      widget.store ??
      (sl.isRegistered<HomeBannerDismissStore>()
          ? sl<HomeBannerDismissStore>()
          : HomeBannerDismissStore());

  String get _key => widget.banner.dismissKey(widget.version);

  bool get _strip => _tapped.contains(_key);

  Map<String, Object> get _properties => {
    'layout_version': widget.version,
    'link_type': widget.banner.link?.scheme ?? 'none',
  };

  ValueListenable<int> get _visits => ScreenTracker.instance.visits;

  @override
  void initState() {
    super.initState();
    final store = _store;
    Future.wait([store.read(), store.tapped()]).then((r) {
      if (mounted) {
        setState(() {
          _dismissed = r[0];
          _tapped = r[1];
        });
      }
    });
    _visits.addListener(_scheduleShown);
  }

  @override
  void dispose() {
    _visits.removeListener(_scheduleShown);
    super.dispose();
  }

  bool get _visible =>
      _dismissed != null &&
      !_dismissed!.contains(_key) &&
      widget.banner.schedule.isActiveAt(widget.now);

  /// `home_banner_shown` once the banner has been drawn with Home on
  /// screen: after the frame, not from build, so a frame for an offstage
  /// tab or a Home under a pushed page does not count.
  void _scheduleShown() {
    if (!mounted || !_visible || HomeBannerSlot._shown.contains(_key)) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_visible) return;
      final current = ScreenTracker.instance.current;
      if (current != null && current != ScreenNames.home) return;
      if (!TickerMode.valuesOf(context).enabled) return;
      if (!HomeBannerSlot._shown.add(_key)) return;
      logAppEvent(
        HomeBannerEvents.shown,
        properties: {..._properties, 'style': _strip ? 'strip' : 'card'},
      );
    });
  }

  void _dismiss() {
    final key = _key;
    logAppEvent(HomeBannerEvents.dismissed, properties: _properties);
    setState(() {
      _animate = true;
      _dismissed = {...?_dismissed, key};
    });
    unawaited(_store.dismiss(key));
    showPrimaryToastWithAction(
      context,
      'Announcement hidden',
      actionLabel: 'Undo',
      onAction: () => _undo(key),
    );
  }

  void _undo(String key) {
    unawaited(_store.undismiss(key));
    logAppEvent(HomeBannerEvents.restored, properties: _properties);
    if (!mounted) return;
    setState(() {
      _animate = true;
      _dismissed = {...?_dismissed}..remove(key);
    });
  }

  void _open() {
    final link = widget.banner.link;
    if (link == null) return;
    logAppEvent(HomeBannerEvents.tapped, properties: _properties);
    final key = _key;
    unawaited(_store.markTapped(key));
    // Shrinks to the strip when the person comes back to Home.
    unawaited(
      openHomeLink(
        context,
        link,
        extra: HomeShelfHeader(
          title: widget.banner.title,
          body: widget.banner.body,
        ),
      ).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _animate = true;
          _tapped = {..._tapped, key};
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    if (visible) _scheduleShown();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final onTap = widget.banner.link == null ? null : _open;
    final child = !visible
        ? const SizedBox(width: double.infinity)
        : Padding(
            // The gap Home puts between shelves, under it.
            padding: const EdgeInsets.fromLTRB(
              ResponsiveCardSizes.homeGutter,
              0,
              ResponsiveCardSizes.homeGutter,
              28,
            ),
            child: _strip && onTap != null
                ? HomeBannerStrip(
                    banner: widget.banner,
                    onTap: onTap,
                    onDismiss: _dismiss,
                  )
                : HomeBannerCard(
                    banner: widget.banner,
                    onTap: onTap,
                    onDismiss: _dismiss,
                  ),
          );
    // Only after a tap here (close, Undo, back from the link): the first
    // paint does not grow in. (A zero-duration AnimatedSize asserts, so
    // without motion there is none.)
    if (!_animate || reduceMotion) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

/// A banner already opened once: one line with its title and an arrow, so
/// it stops taking a card's room on every return but stays one tap away.
class HomeBannerStrip extends StatelessWidget {
  const HomeBannerStrip({
    super.key,
    required this.banner,
    required this.onTap,
    required this.onDismiss,
  });

  final HomeBanner banner;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(HomeBannerCard._radius),
      child: ColoredBox(
        color: scheme.primary20,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: [banner.title, ?banner.ctaLabel].join(', '),
                excludeSemantics: true,
                child: AdaptiveTap(
                  onTap: onTap,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              banner.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.bodySmallMed.copyWith(
                                color: scheme.black,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            LucideIcons.chevronRight,
                            size: 20,
                            color: scheme.primary100,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _CloseButton(onTap: onDismiss, overImage: false),
          ],
        ),
      ),
    );
  }
}

/// One announcement: title, a line of body and a pill button on the left,
/// the image filling the right edge, a close button in the top corner. A
/// sage card on Home's white, flat (no shadow) like every Nook card.
class HomeBannerCard extends StatelessWidget {
  const HomeBannerCard({
    super.key,
    required this.banner,
    required this.onTap,
    required this.onDismiss,
  });

  final HomeBanner banner;

  /// Null when the banner has no link: the card is then not a button.
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  static const double _radius = 12;
  static const double _imageWidth = 112;
  static const double _minHeightWithImage = 128;

  /// From this text scale the image moves above the copy, so the copy gets
  /// the card's full width (at 2.0 the side image left the button
  /// ellipsized).
  static const double stackAtScale = 1.6;

  static bool stacksAt(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(100) >= stackAtScale * 100;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = context.textTheme;
    final imageUrl = banner.imageUrl;
    final hasImage = imageUrl != null;
    final cta = banner.ctaLabel;
    final body = banner.body;
    final stacked = hasImage && stacksAt(context);

    final copy = Padding(
      // Room on the right for the close button when it sits on the copy.
      padding: EdgeInsets.fromLTRB(16, 16, hasImage ? 16 : 48, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            banner.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: text.titleMediumSemi.copyWith(
              color: scheme.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(
              body,
              maxLines: stacked ? 4 : 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                color: scheme.black,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          if (cta != null && onTap != null) ...[
            const SizedBox(height: 12),
            _Pill(label: cta),
          ],
        ],
      ),
    );

    final image = hasImage
        ? CachedNetworkImage(
            imageUrl: imageUrl,
            cacheManager: CustomCacheManager.instance,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => ColoredBox(
              color: scheme.primary40,
              child: Icon(
                LucideIcons.coffee,
                size: 24,
                color: scheme.primary100,
              ),
            ),
          )
        : null;

    final content = image == null
        ? copy
        : stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(aspectRatio: 16 / 9, child: image),
              copy,
            ],
          )
        : IntrinsicHeight(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minHeightWithImage),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: copy),
                  SizedBox(width: _imageWidth, child: image),
                ],
              ),
            ),
          );

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: ColoredBox(color: scheme.primary20, child: content),
    );

    final tappable = onTap == null
        ? card
        : Semantics(
            button: true,
            label: [banner.title, ?body, ?cta].join(', '),
            excludeSemantics: true,
            child: AdaptiveTap(
              onTap: onTap,
              borderRadius: BorderRadius.circular(_radius),
              child: card,
            ),
          );

    return Stack(
      children: [
        tappable,
        Positioned(
          top: 0,
          right: 0,
          child: _CloseButton(onTap: onDismiss, overImage: hasImage),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary100,
        borderRadius: BorderRadius.circular(999),
      ),
      // Wraps to a second line at large text rather than hiding where the
      // tap goes.
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodySmallMed.copyWith(
          color: scheme.white,
          fontSize: 13,
          height: 1.2,
        ),
      ),
    );
  }
}

/// A 48dp target in the card's top corner. Over a photo the glyph sits on a
/// 28px white disc so it reads on any image.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap, required this.overImage});

  final VoidCallback onTap;
  final bool overImage;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final glyph = Icon(LucideIcons.x, size: 16, color: scheme.black);
    return Semantics(
      button: true,
      label: 'Close announcement',
      excludeSemantics: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: overImage
                ? Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: glyph,
                  )
                : glyph,
          ),
        ),
      ),
    );
  }
}
