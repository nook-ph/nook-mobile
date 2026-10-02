import 'package:flutter/material.dart';
import 'package:nook/features/map/presentation/widgets/map_tokens.dart';

/// "Updating" pill under the search field while a viewport refetch runs.
/// Non-blocking: pointer events pass through.
class MapUpdatingChip extends StatelessWidget {
  const MapUpdatingChip({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        label: 'Updating cafes',
        excludeSemantics: true,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: MapTokens.surface,
            borderRadius: BorderRadius.circular(100),
            boxShadow: MapTokens.floatShadow(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: MapTokens.brand,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Updating',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: MapTokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
