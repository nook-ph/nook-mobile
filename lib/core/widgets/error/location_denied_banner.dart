import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/utils/adaptive_tap.dart';

/// Dismissible notice that nearby sorting and distances are unavailable.
///
/// A soft row, not an alert: the feed still works without location. Two
/// cases share it: permission denied (the default copy, opens the app's
/// settings) and [LocationDeniedBanner.servicesOff] (the phone-wide switch,
/// opens the system location settings).
///
/// [visible] is driven by BLoC state. [onDismiss] should clear that flag in
/// your state layer.
class LocationDeniedBanner extends StatelessWidget {
  const LocationDeniedBanner({
    super.key,
    required this.visible,
    this.onDismiss,
    this.onOpenSettings,
    this.title = 'See cafes near you',
    this.actionLabel = 'Turn on location',
  });

  /// The variant for Location Services being off for the whole phone.
  const LocationDeniedBanner.servicesOff({
    super.key,
    required this.visible,
    this.onDismiss,
    this.onOpenSettings = Geolocator.openLocationSettings,
  }) : title = 'Location Services are off',
       actionLabel = 'Open Settings';

  final bool visible;

  /// Invoked when the user taps the close control; should update BLoC/UI
  /// so [visible] becomes false.
  final VoidCallback? onDismiss;

  /// Defaults to [Geolocator.openAppSettings].
  final Future<bool> Function()? onOpenSettings;

  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    final textTheme = context.textTheme;
    final scheme = context.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.offWhite,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: AdaptiveTap(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final open = onOpenSettings ?? Geolocator.openAppSettings;
                  unawaited(open());
                },
                child: Padding(
                  // Figma: 12 / 14 padding, 10 between icon, text and close.
                  padding: EdgeInsets.fromLTRB(
                    14,
                    12,
                    onDismiss != null ? 0 : 14,
                    12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.locate,
                        size: 18,
                        color: scheme.primary100,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: textTheme.bodyMediumMed.copyWith(
                                color: scheme.black,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            Text(
                              actionLabel,
                              style: textTheme.bodySmallMed.copyWith(
                                color: scheme.primary100,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onDismiss != null)
              AdaptiveTap(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(22),
                child: Semantics(
                  button: true,
                  label: 'Dismiss',
                  // A 14pt glyph 14 from the edge and 10 from the text, in
                  // a touch target that stays 44 tall.
                  child: Container(
                    width: 38,
                    height: 44,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(LucideIcons.x, size: 14, color: scheme.gray),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
