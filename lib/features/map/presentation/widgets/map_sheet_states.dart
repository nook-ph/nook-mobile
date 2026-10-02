import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/app_error_copy.dart';
import 'package:nook/core/utils/error_info.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';

/// What the map sheet shows in place of its list when there is nothing to
/// list: an icon in a grey circle, a title, one line, and at most one button.
/// The map, search field and (except for load errors) the chips stay visible
/// around it.
class MapSheetStateView extends StatelessWidget {
  const MapSheetStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.primaryAction = true,
    this.iconColor = MapTokens.brand,
  });

  /// "No cafes in this area": the sheet keeps its chips, so the button is the
  /// outlined one and clears what the chips show.
  factory MapSheetStateView.noCafes({VoidCallback? onClearFilters}) {
    return MapSheetStateView(
      icon: LucideIcons.map,
      iconColor: MapTokens.ink,
      title: 'No cafes in this area',
      subtitle: 'Try zooming out or adjusting filters.',
      actionLabel: onClearFilters == null ? null : 'Clear filters',
      onAction: onClearFilters,
      primaryAction: false,
    );
  }

  /// A failed load, with the icon and copy for its kind. A session that ran
  /// out offers Sign in; everything else offers Try again.
  factory MapSheetStateView.error({
    required Object error,
    required VoidCallback onRetry,
    required VoidCallback onSignIn,
  }) {
    final info = AppErrorCopy.fromException(error);
    final signedOut = info.type == ErrorType.sessionExpired;
    return MapSheetStateView(
      icon: mapErrorIcon(info.type),
      title: info.title,
      subtitle: info.subtitle,
      actionLabel: signedOut ? 'Sign in' : 'Try again',
      onAction: signedOut ? onSignIn : onRetry,
    );
  }

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Filled green when true, outlined when false.
  final bool primaryAction;

  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = actionLabel;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFEEEEEE),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MapTokens.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: MapTokens.muted,
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: 24),
            MapPillButton(label: label, filled: primaryAction, onTap: onAction),
          ],
        ],
      ),
    );
  }
}

/// The icon each kind of load failure uses across the app's error states.
IconData mapErrorIcon(ErrorType type) => switch (type) {
  ErrorType.offline => LucideIcons.wifiOff,
  ErrorType.sessionExpired => LucideIcons.lock,
  ErrorType.serverError || ErrorType.unknown => LucideIcons.triangleAlert,
};

/// A 44pt pill: green with white text, or white with a grey outline.
class MapPillButton extends StatelessWidget {
  const MapPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  /// Stretch to the available width instead of hugging the label.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? MapTokens.brand : MapTokens.surface,
        borderRadius: BorderRadius.circular(100),
        border: filled ? null : Border.all(color: MapTokens.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: filled ? MapTokens.surface : MapTokens.ink,
        ),
      ),
    );
    return Semantics(
      button: true,
      child: AdaptiveTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: expand ? child : IntrinsicWidth(child: child),
      ),
    );
  }
}

/// First load: grey blocks in the shape of the count line and four list rows
/// (76pt photo, three text lines), so nothing jumps when the cafes arrive.
class MapSheetSkeleton extends StatelessWidget {
  const MapSheetSkeleton({super.key, this.rows = 4});

  final int rows;

  static const _fill = Color(0xFFEEEEEE);

  static Widget _bar(double width, double height, {double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading cafes',
      excludeSemantics: true,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(MapTokens.gutter, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(110, 12),
            for (var i = 0; i < rows; i++) ...[
              SizedBox(height: i == 0 ? 20 : 16),
              Row(
                children: [
                  _bar(76, 76, radius: 12),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(150, 10),
                      const SizedBox(height: 10),
                      _bar(110, 10),
                      const SizedBox(height: 10),
                      _bar(130, 10),
                    ],
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

/// Shown when location permission is permanently denied, before sending the
/// user to Settings. Resolves true when they chose Open Settings.
Future<bool> showMapLocationDeniedDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) {
      final textTheme = Theme.of(context).textTheme;
      return Dialog(
        backgroundColor: MapTokens.surface,
        surfaceTintColor: MapTokens.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Location is off for Nook',
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MapTokens.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Turn it on in Settings to center the map on you and sort '
                'cafes by distance.',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: MapTokens.muted,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: MapPillButton(
                      label: 'Not now',
                      filled: false,
                      expand: true,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MapPillButton(
                      label: 'Open Settings',
                      expand: true,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
