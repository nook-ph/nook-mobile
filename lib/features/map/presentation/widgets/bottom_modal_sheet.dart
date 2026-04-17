import 'package:flutter/material.dart';
import 'package:sliding_panel_kit/sliding_panel_kit.dart';
import 'package:nook/features/map/presentation/widgets/cafe_card.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';

class BottomModalSheet extends StatefulWidget {
  final List<CafeSummary> cafes;
  const BottomModalSheet({super.key, required this.cafes});

  @override
  State<BottomModalSheet> createState() => _BottomModalSheetState();
}

class _BottomModalSheetState extends State<BottomModalSheet> {
  final controller = SlidingPanelController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlidingPanelBuilder(
      controller: controller,
      snapConfig: SlidingPanelSnapConfig(
        extents: [0.06, 0.85],
        velocityRange: (400, 2400),
        animation: SpringSnapAnimation.fixed(
          SpringDescription(mass: 1, stiffness: 350, damping: 30),
        ),
      ),

      // other options: consider them !!
      // SpringSnapAnimation()
      // SpringSnapAnimation.adaptive()
      // CurvedSnapAnimation()
      handle: const SlidingPanelHandle(),
      builder: (context, handle) {
        return SlidingPanelBody(
          shadowColor: Colors.transparent,
          child: Column(
            children: [
              if (handle != null) handle,
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 48,
                  ),
                  itemCount: widget.cafes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 36),
                  itemBuilder: (BuildContext context, int index) {
                      return CafeCard(cafe: widget.cafes[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
