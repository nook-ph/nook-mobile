import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';

/// Bone colour while the cafe loads; the pulse brightens it slightly.
const _bone = Color(0xFFEEEEEE);
const _pulse = PulseEffect(from: _bone, to: Color(0xFFF6F6F6));

/// The sheet's shape while the cafe loads: name, area and status lines, the
/// two action pills, then an amenities grid and a row of chips, so nothing
/// jumps when the data arrives.
class CafeDetailsSkeleton extends StatelessWidget {
  const CafeDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    const rowGap = SizedBox(height: 12);
    const amenityRow = Row(
      children: [
        Expanded(child: Bone(height: 36, uniRadius: 18)),
        SizedBox(width: 12),
        Expanded(child: Bone(height: 36, uniRadius: 18)),
      ],
    );

    return Semantics(
      label: 'Loading cafe details',
      child: Skeletonizer.zone(
        effect: _pulse,
        // The photo runs 24 under the sheet; the sheet pads 28 above the
        // name, so 4 more here.
        child: const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            children: [
              Bone(width: 170, height: 26, uniRadius: 6),
              gap,
              Bone(width: 120, height: 14, uniRadius: 6),
              gap,
              Bone(width: 240, height: 14, uniRadius: 6),
              gap,
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Expanded(child: Bone(height: 44, uniRadius: 22)),
                    SizedBox(width: 8),
                    Expanded(child: Bone(height: 44, uniRadius: 22)),
                  ],
                ),
              ),
              gap,
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Bone(width: 90, height: 18, uniRadius: 6),
                    rowGap,
                    amenityRow,
                    rowGap,
                    amenityRow,
                    rowGap,
                    Bone(width: 70, height: 18, uniRadius: 6),
                    rowGap,
                    Row(
                      children: [
                        Bone(width: 104, height: 30, uniRadius: 15),
                        SizedBox(width: 8),
                        Bone(width: 90, height: 30, uniRadius: 15),
                        SizedBox(width: 8),
                        Bone(width: 124, height: 30, uniRadius: 15),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The pinned bar's shape while the cafe loads: two text lines on the left,
/// the Directions pill on the right.
class CafeActionsBarSkeleton extends StatelessWidget {
  const CafeActionsBarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFEFEFE),
          border: Border(top: BorderSide(color: CafeDetailsTokens.border)),
        ),
        child: SafeArea(
          top: false,
          child: Skeletonizer.zone(
            effect: _pulse,
            child: const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Bone(width: 90, height: 14, uniRadius: 6),
                        SizedBox(height: 6),
                        Bone(width: 120, height: 12, uniRadius: 6),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Bone(width: 140, height: 44, uniRadius: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
