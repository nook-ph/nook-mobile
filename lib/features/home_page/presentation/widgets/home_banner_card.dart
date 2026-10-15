import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/analytics/log_app_event.dart';
import 'package:nook/core/analytics/retention_tracking_events.dart';
import 'package:nook/core/cache/custom_cache_manager.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/responsive_card_sizes.dart';
import 'package:nook/features/home_page/data/home_banner_dismiss_store.dart';
import 'package:nook/features/home_page/domain/home_layout.dart';
import 'package:nook/features/home_page/presentation/home_link.dart';
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

  HomeBannerDismissStore get _store =>
      widget.store ??
      (sl.isRegistered<HomeBannerDismissStore>()
          ? sl<HomeBannerDismissStore>()
          : HomeBannerDismissStore());

  String get _key => widget.banner.dismissKey(widget.version);

  Map<String, Object> get _properties => {
    'layout_version': widget.version,
    'link_type': widget.banner.link?.scheme ?? 'none',
  };

  @override
  void initState() {
    super.initState();
    _store.read().then((keys) {
      if (mounted) setState(() => _dismissed = keys);
    });
  }

  bool get _visible =>
      _dismissed != null &&
      !_dismissed!.contains(_key) &&
      widget.banner.schedule.isActiveAt(widget.now);

  void _dismiss() {
    logAppEvent(HomeBannerEvents.dismissed, properties: _properties);
    setState(() => _dismissed = {...?_dismissed, _key});
    unawaited(_store.dismiss(_key));
  }

  void _open() {
    final link = widget.banner.link;
    if (link == null) return;
    logAppEvent(HomeBannerEvents.tapped, properties: _properties);
    unawaited(openHomeLink(context, link));
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    if (HomeBannerSlot._shown.add(_key)) {
      logAppEvent(HomeBannerEvents.shown, properties: _properties);
    }
    return Padding(
      // The gap Home puts between shelves, under it.
      padding: const EdgeInsets.fromLTRB(
        ResponsiveCardSizes.homeGutter,
        0,
        ResponsiveCardSizes.homeGutter,
        28,
      ),
      child: HomeBannerCard(
        banner: widget.banner,
        onTap: widget.banner.link == null ? null : _open,
        onDismiss: _dismiss,
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

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final text = context.textTheme;
    final imageUrl = banner.imageUrl;
    final hasImage = imageUrl != null;
    final cta = banner.ctaLabel;
    final body = banner.body;

    final copy = Padding(
      // Room on the right for the close button when it sits on the copy.
      padding: EdgeInsets.fromLTRB(16, 16, hasImage ? 16 : 44, 16),
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
              maxLines: 2,
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

    final content = hasImage
        ? IntrinsicHeight(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minHeightWithImage),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: copy),
                  SizedBox(
                    width: _imageWidth,
                    child: CachedNetworkImage(
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
                    ),
                  ),
                ],
              ),
            ),
          )
        : copy;

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
      child: Text(
        label,
        maxLines: 1,
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

/// A 44pt target in the card's top corner. Over a photo the glyph sits on a
/// small white disc so it reads on any image.
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
        borderRadius: BorderRadius.circular(22),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: overImage
                ? Container(
                    width: 24,
                    height: 24,
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
