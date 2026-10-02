import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/features/cafe_details/domain/use_cases/get_cafe_details_usecase.dart';
import 'package:nook/features/cafe_details/presentation/utils/cafe_open_status.dart';
import 'package:nook/features/cafe_details/presentation/utils/launch_cafe_directions.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Sticky bottom bar on cafe details: how far and whether it is open on the
/// left, Get Directions on the right. Directions is the funnel's conversion
/// event; pinning it keeps it one tap away at any scroll depth, and the
/// status beside it answers "can I go now" after the header scrolls away.
///
/// Been / Want to Try live under the cafe's name (see `CafeStatusPills`).
class CafeActionsBar extends StatelessWidget {
  const CafeActionsBar({super.key, required this.cafe});

  final CafeDetailsResult cafe;

  @override
  Widget build(BuildContext context) {
    final details = cafe.cafeDetails;
    final status = CafeOpenStatus.resolve(
      details.operatingHours,
      DateTime.now(),
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: CafeDetailsTokens.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CafeDetailsTokens.gutter,
            12,
            CafeDetailsTokens.gutter,
            12,
          ),
          child: CafeDistanceBuilder(
            lat: details.lat,
            lng: details.lng,
            builder: (context, distance) {
              final summary = _Summary(distance: distance, status: status);
              final button = _DirectionsButton(cafe: cafe);

              // With neither a distance nor hours there is nothing to say
              // beside the button, so it takes the whole bar.
              if (!summary.hasContent) return button;

              // At large text sizes the summary and the button stack, so
              // neither truncates and the target stays 48pt tall.
              final scale = MediaQuery.textScalerOf(context).scale(15) / 15;
              if (scale > 1.3) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [summary, const SizedBox(height: 8), button],
                );
              }

              return Row(
                children: [
                  Expanded(child: summary),
                  const SizedBox(width: 12),
                  button,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.distance, required this.status});

  final String? distance;
  final CafeOpenStatus status;

  bool get hasContent => distance != null || status.hasAnyHours;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusText = status.barText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (distance != null)
          Text(
            '$distance away',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: CafeDetailsTokens.ink,
            ),
          ),
        if (status.hasAnyHours)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: CafeDetailsTokens.statusDot(status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: CafeDetailsTokens.muted,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _DirectionsButton extends StatelessWidget {
  const _DirectionsButton({required this.cafe});

  final CafeDetailsResult cafe;

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: () => launchCafeDirections(context, cafe),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        decoration: BoxDecoration(
          color: CafeDetailsTokens.brand,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIcons.navigationArrow(PhosphorIconsStyle.fill),
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Directions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
