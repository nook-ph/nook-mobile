import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class AdaptiveTap extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const AdaptiveTap({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIos) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: child,
      );
    }

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(borderRadius: borderRadius, onTap: onTap, child: child),
    );
  }
}
