import 'package:flutter/material.dart';

// Measures the height of [prototype] at runtime and constrains
// [listView] to that height. Works at any text scale

// basically used for horizontal listviews so that height is
// no longer hard coded

class PrototypeHeight extends StatelessWidget {
  final Widget prototype;
  final ListView listView;

  const PrototypeHeight({
    super.key,
    required this.prototype,
    required this.listView,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IgnorePointer(child: Opacity(opacity: 0.0, child: prototype)),
        const SizedBox(width: double.infinity),
        Positioned.fill(child: listView),
      ],
    );
  }
}
