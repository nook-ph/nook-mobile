import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Platform-adaptive elevated button.
///
/// - On iOS, renders as a [CupertinoButton] with the [style]'s background,
///   foreground, border, padding, shape, and disabled states applied via a
///   [Container]. Native Cupertino pressed-opacity feedback is used instead
///   of the Material ink splash.
/// - On Android / other platforms, delegates to the standard [ElevatedButton]
///   preserving all Material behavior (elevation, ripple, theme integration).
class AdaptiveElevatedButton extends StatelessWidget {
  const AdaptiveElevatedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _AdaptiveCupertinoButton(
        onPressed: onPressed,
        style: style,
        variant: _AdaptiveCupertinoVariant.elevated,
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: child,
    );
  }
}

/// Platform-adaptive text button.
///
/// - On iOS, renders as a [CupertinoButton] styled from [style] (color,
///   padding). Disabled state is handled by Cupertino's built-in opacity.
/// - On Android / other platforms, delegates to the standard [TextButton].
class AdaptiveTextButton extends StatelessWidget {
  const AdaptiveTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _AdaptiveCupertinoButton(
        onPressed: onPressed,
        style: style,
        variant: _AdaptiveCupertinoVariant.text,
        child: child,
      );
    }
    return TextButton(
      onPressed: onPressed,
      style: style,
      child: child,
    );
  }
}

/// Platform-adaptive outlined button.
///
/// - On iOS, renders as a [CupertinoButton] wrapped in a [Container] that
///   paints the [style.side] border. The default [CupertinoButton] background
///   is transparent so the border is visible.
/// - On Android / other platforms, delegates to the standard [OutlinedButton].
class AdaptiveOutlinedButton extends StatelessWidget {
  const AdaptiveOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _AdaptiveCupertinoButton(
        onPressed: onPressed,
        style: style,
        variant: _AdaptiveCupertinoVariant.outlined,
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: style,
      child: child,
    );
  }
}

/// Platform-adaptive filled button.
///
/// - On iOS, renders as a [CupertinoButton] wrapped in a [Container] using
///   the [style]'s background and shape.
/// - On Android / other platforms, delegates to the standard [FilledButton].
class AdaptiveFilledButton extends StatelessWidget {
  const AdaptiveFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return _AdaptiveCupertinoButton(
        onPressed: onPressed,
        style: style,
        variant: _AdaptiveCupertinoVariant.filled,
        child: child,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: style,
      child: child,
    );
  }
}

enum _AdaptiveCupertinoVariant { elevated, text, outlined, filled }

/// Internal: builds a [CupertinoButton] whose visual appearance matches the
/// Material [ButtonStyle] passed in (background, foreground, border, padding,
/// shape, disabled states).
class _AdaptiveCupertinoButton extends StatelessWidget {
  const _AdaptiveCupertinoButton({
    required this.onPressed,
    required this.child,
    required this.style,
    required this.variant,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final _AdaptiveCupertinoVariant variant;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final theme = Theme.of(context);
    final states = isEnabled
        ? const <WidgetState>{}
        : const <WidgetState>{WidgetState.disabled};

    final backgroundColor = _resolve<Color?>(style?.backgroundColor, states);
    final foregroundColor = _resolve<Color?>(style?.foregroundColor, states);
    final side = _resolve<BorderSide?>(style?.side, states);
    final shape = _resolve<OutlinedBorder?>(style?.shape, states);
    final padding = _resolve<EdgeInsetsGeometry?>(style?.padding, states);
    final minSize = _resolve<Size?>(style?.minimumSize, states);
    final fixedSize = _resolve<Size?>(style?.fixedSize, states);

    final resolvedBackground = backgroundColor ?? _defaultBackground(theme);
    final resolvedForeground = foregroundColor ?? _defaultForeground(theme);
    final resolvedPadding = padding ?? const EdgeInsets.symmetric(vertical: 14);
    final resolvedBorderRadius = shape is RoundedRectangleBorder
        ? shape.borderRadius as BorderRadius?
        : null;
    final constraints = _buildConstraints(minSize, fixedSize);

    final container = Container(
      padding: resolvedPadding,
      constraints: constraints,
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: resolvedBorderRadius,
        border: side == null || side == BorderSide.none
            ? null
            : Border.fromBorderSide(side.copyWith(color: resolvedForeground)),
      ),
      child: DefaultTextStyle(
        style: (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
          color: resolvedForeground,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
        child: IconTheme.merge(
          data: IconThemeData(color: resolvedForeground),
          child: child,
        ),
      ),
    );

    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        primaryColor: resolvedForeground,
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        borderRadius: resolvedBorderRadius,
        onPressed: onPressed,
        child: Semantics(
          button: true,
          enabled: isEnabled,
          child: container,
        ),
      ),
    );
  }

  T? _resolve<T>(WidgetStateProperty<T>? property, Set<WidgetState> states) {
    return property?.resolve(states);
  }

  BoxConstraints? _buildConstraints(Size? minSize, Size? fixedSize) {
    if (fixedSize != null) {
      return BoxConstraints.tight(fixedSize);
    }
    if (minSize != null) {
      return BoxConstraints(
        minWidth: minSize.width,
        minHeight: minSize.height,
      );
    }
    return null;
  }

  Color? _defaultBackground(ThemeData theme) {
    switch (variant) {
      case _AdaptiveCupertinoVariant.elevated:
      case _AdaptiveCupertinoVariant.filled:
        return theme.colorScheme.primary;
      case _AdaptiveCupertinoVariant.outlined:
      case _AdaptiveCupertinoVariant.text:
        return null;
    }
  }

  Color _defaultForeground(ThemeData theme) {
    switch (variant) {
      case _AdaptiveCupertinoVariant.elevated:
      case _AdaptiveCupertinoVariant.filled:
        return theme.colorScheme.onPrimary;
      case _AdaptiveCupertinoVariant.outlined:
        return theme.colorScheme.primary;
      case _AdaptiveCupertinoVariant.text:
        return theme.colorScheme.primary;
    }
  }
}
