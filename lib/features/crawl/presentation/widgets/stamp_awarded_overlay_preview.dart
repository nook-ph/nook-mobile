import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:nook/features/crawl/presentation/widgets/stamp_awarded_overlay.dart';

@Preview(name: 'Stop 5 claimed', group: 'Stamp Awarded Overlay')
Widget stampAwardedOverlayPreview() {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: Colors.white),
          ),
          const StampAwardedOverlay(stopOrder: 5),
        ],
      ),
    ),
  );
}
