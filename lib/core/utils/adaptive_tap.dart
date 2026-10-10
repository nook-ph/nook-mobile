import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AdaptiveTap extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;

  const AdaptiveTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIos) {
      final colorScheme = Theme.of(context).colorScheme;

      // CupertinoButton is only here for its pressed-opacity feedback; the
      // child must lay out exactly as it does inside the InkWell below. Left
      // to its defaults it would centre the child in any extra space, grow
      // it to 44×44, and restyle unstyled text in the system font and icons
      // in the button colour — none of which happens on Android.
      final button = CupertinoTheme(
        data: CupertinoTheme.of(
          context,
        ).copyWith(primaryColor: colorScheme.onSurface),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          alignment: AlignmentDirectional.topStart,
          onPressed: onTap,
          child: DefaultTextStyle(
            style: DefaultTextStyle.of(context).style,
            child: IconTheme(data: IconTheme.of(context), child: child),
          ),
        ),
      );

      // CupertinoButton has no long-press callback of its own.
      if (onLongPress == null) return button;
      return GestureDetector(onLongPress: onLongPress, child: button);
    }

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }
}
