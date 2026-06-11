import 'package:flutter/material.dart';

class SlideUpOverlay extends StatelessWidget {
  final bool visible;
  final Widget child;
  final Duration duration;
  final Curve switchInCurve;
  final Curve switchOutCurve;

  const SlideUpOverlay({
    super.key,
    required this.visible,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
    this.switchInCurve = Curves.easeOutCubic,
    this.switchOutCurve = Curves.easeInCubic,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: switchInCurve,
      switchOutCurve: switchOutCurve,
      transitionBuilder: (child, animation) {
        final isExiting = animation.status == AnimationStatus.reverse;
        final offsetAnimation = isExiting
            ? Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(0, 1.1),
              ).animate(ReverseAnimation(animation))
            : Tween<Offset>(
                begin: const Offset(0, 1.1),
                end: Offset.zero,
              ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: offsetAnimation,
            child: child,
          ),
        );
      },
      child: visible ? child : const SizedBox.shrink(),
    );
  }
}
