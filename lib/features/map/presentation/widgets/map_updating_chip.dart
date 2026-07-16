import 'package:flutter/material.dart';
import 'package:nook/utils/theme/custom_themes/text_theme.dart';

/// Floating "Updating" pill shown at the top of the map while a viewport
/// refetch is in flight — port of the webapp's loader chip (`MapExplorer`).
/// Non-blocking: pointer events pass through.
class MapUpdatingChip extends StatelessWidget {
  const MapUpdatingChip({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE4E4E7)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LoadingDots(color: Color(0xFF3A5A40)),
            const SizedBox(width: 8),
            Text(
              'Updating',
              style: Theme.of(
                context,
              ).textTheme.bodySmallMed.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three dots pulsing in sequence.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots({required this.color});

  final Color color;

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value - i * 0.2) % 1.0;
            final t = phase < 0 ? phase + 1.0 : phase;
            // Rise and fall quickly, then rest.
            final pulse = t < 0.4 ? (1 - (t / 0.4 - 0.5).abs() * 2) : 0.0;
            final opacity = 0.35 + 0.65 * pulse;
            return Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
