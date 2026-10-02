import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/utils/geo.dart';
import 'package:nook/features/map/presentation/widgets/map_sheet_cafe_card.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';

/// The preview shown when a pin is selected: the list row in a floating card,
/// with a small close button on its top-right corner.
class CafeOverlayCard extends StatefulWidget {
  final CafeSummary cafe;
  final VoidCallback onClose;

  /// Reports the card's laid-out height, so the map can keep the recenter
  /// button above it. The card hugs its content, so this varies by cafe.
  final ValueChanged<double>? onHeight;

  const CafeOverlayCard({
    super.key,
    required this.cafe,
    required this.onClose,
    this.onHeight,
    this.distanceFrom,
  });

  /// The place distances are measured from; null means the phone.
  final GeoPoint? distanceFrom;

  static const double _padding = 12;

  /// The shortest the card gets: the 76pt photo plus padding.
  static const double minHeight = MapSheetCafeCard.photoSize + _padding * 2;

  @override
  State<CafeOverlayCard> createState() => _CafeOverlayCardState();
}

class _CafeOverlayCardState extends State<CafeOverlayCard> {
  final _cardKey = GlobalKey();
  double? _reported;

  void _reportHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _cardKey.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final height = box.size.height;
      if (_reported == height) return;
      _reported = height;
      widget.onHeight?.call(height);
    });
  }

  @override
  Widget build(BuildContext context) {
    _reportHeight();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          key: _cardKey,
          padding: const EdgeInsets.all(CafeOverlayCard._padding),
          decoration: BoxDecoration(
            color: MapTokens.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => MapSheetCafeCard(
              width: constraints.maxWidth,
              cafe: widget.cafe,
              showUnratedArea: false,
              distanceFrom: widget.distanceFrom,
            ),
          ),
        ),
        Positioned(
          top: -16,
          right: -16,
          child: Semantics(
            button: true,
            label: 'Close preview',
            excludeSemantics: true,
            child: AdaptiveTap(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(22),
              // 44pt target around the 28pt circle.
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: MapTokens.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.x,
                    size: 14,
                    color: MapTokens.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
