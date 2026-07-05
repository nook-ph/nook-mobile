import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';

/// Dismissible banner when location permission blocks nearby sorting.
///
/// [visible] is driven by BLoC state (e.g. `locationDenied`). [onDismiss]
/// should clear that flag in your state layer.
class LocationDeniedBanner extends StatelessWidget {
  const LocationDeniedBanner({
    super.key,
    required this.visible,
    this.onDismiss,
    this.onOpenSettings,
  });

  final bool visible;

  /// Invoked when the user taps the close control; should update BLoC/UI
  /// so [visible] becomes false.
  final VoidCallback? onDismiss;

  /// Defaults to [Geolocator.openAppSettings].
  final Future<bool> Function()? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Material(
        color: context.colorScheme.primary60,
        borderRadius: BorderRadius.circular(8),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(
                        'See cafes near you',
                        style: textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.white,
                        ),
                      ),
                      Text(
                        '·',
                        style: textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.white,
                        ),
                      ),
                      AdaptiveTextButton(
                        onPressed: () {
                          final open =
                              onOpenSettings ?? Geolocator.openAppSettings;
                          unawaited(open());
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: context.colorScheme.white,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Turn on location',
                          style: textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onDismiss != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: AdaptiveTap(
                    onTap: onDismiss,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: context.colorScheme.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
