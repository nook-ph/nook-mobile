import 'package:flutter/material.dart';
import 'package:nook/features/cafe_details/presentation/widgets/review_filter_bottom_sheet.dart';

class RatingReviewSummary extends StatelessWidget {
  const RatingReviewSummary({
    super.key,
    this.rating = 0,
    this.reviewCount = 0,
    this.onWriteReviewTap,
    this.distribution,
  });

  final double rating;
  final int reviewCount;
  final VoidCallback? onWriteReviewTap;
  final List<RatingDistributionData>? distribution;

  void _showFilterBottomSheet(BuildContext context) {
    ReviewFilterBottomSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    const defaultDistribution = <RatingDistributionData>[
      RatingDistributionData(star: 5, fill: 0),
      RatingDistributionData(star: 4, fill: 0),
      RatingDistributionData(star: 3, fill: 0),
      RatingDistributionData(star: 2, fill: 0),
      RatingDistributionData(star: 1, fill: 0),
    ];

    final resolvedDistribution = distribution ?? defaultDistribution;

    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.black, size: 32),
                const SizedBox(width: 8),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$reviewCount Reviews',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF616161),
              ),
            ),
            const SizedBox(height: 20),
            _RatingDistributionList(rows: resolvedDistribution),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onWriteReviewTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF344E41),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Write a Review',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE7E7E7)),
            InkWell(
              onTap: () => _showFilterBottomSheet(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sort by: Recommended',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF616161),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: Color(0xFF616161),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingDistributionList extends StatelessWidget {
  const _RatingDistributionList({required this.rows});

  final List<RatingDistributionData> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: rows
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RatingDistributionRow(star: row.star, fill: row.fill),
            ),
          )
          .toList(),
    );
  }
}

class _RatingDistributionRow extends StatelessWidget {
  const _RatingDistributionRow({required this.star, required this.fill});

  final int star;
  final double fill;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 12,
          child: Text(
            '$star',
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF616161),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: const Color(0xFFE0E0E0)),
                  FractionallySizedBox(
                    widthFactor: fill,
                    alignment: Alignment.centerLeft,
                    child: Container(color: const Color(0xFF588157)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class RatingDistributionData {
  const RatingDistributionData({required this.star, required this.fill});

  final int star;
  final double fill;
}
