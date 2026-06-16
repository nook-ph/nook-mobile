import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

    return Material(
      color: Colors.grey.shade200,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 0,
                  children: [
                    Text(
                      'Nearby sorting unavailable',
                      style: textTheme.bodyMedium?.copyWith(
                        color: Colors.black,
                      ),
                    ),
                    AdaptiveTextButton(
                      onPressed: () {
                        final open = onOpenSettings ?? Geolocator.openAppSettings;
                        unawaited(open());
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Open Settings',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                AdaptiveTap(
                  onTap: onDismiss,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.close, color: Colors.grey.shade800),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
