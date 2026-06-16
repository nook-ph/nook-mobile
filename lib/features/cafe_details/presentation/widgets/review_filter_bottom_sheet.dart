import 'package:flutter/material.dart';
import 'package:nook/core/extensions/extensions.dart';
import 'package:nook/core/presentation/widgets/adaptive_buttons.dart';
import 'package:nook/core/utils/adaptive_tap.dart';

typedef ReviewFilterResult = ({String sort, int? ratingFilter});

class ReviewFilterBottomSheet extends StatefulWidget {
  const ReviewFilterBottomSheet({
    super.key,
    required this.ratingCounts,
    required this.initialSort,
    this.initialRatingFilter,
  });

  final Map<int, int> ratingCounts;
  final String initialSort;
  final int? initialRatingFilter;

  static Future<ReviewFilterResult?> show(
    BuildContext context, {
    required Map<int, int> ratingCounts,
    String initialSort = 'recommended',
    int? initialRatingFilter,
  }) {
    return showModalBottomSheet<ReviewFilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ReviewFilterBottomSheet(
        ratingCounts: ratingCounts,
        initialSort: initialSort,
        initialRatingFilter: initialRatingFilter,
      ),
    );
  }

  @override
  State<ReviewFilterBottomSheet> createState() =>
      _ReviewFilterBottomSheetState();
}

class _ReviewFilterBottomSheetState extends State<ReviewFilterBottomSheet> {
  late String _selectedSort;
  late int? _selectedRatingFilter;

  static const List<({String value, String label})> _sortOptions = [
    (value: 'recommended', label: 'Recommended'),
    (value: 'recently_added', label: 'Recently Added'),
    (value: 'highest_rated', label: 'Highest Rated'),
    (value: 'most_helpful', label: 'Most Helpful'),
  ];

  static const List<int> _ratingStars = [5, 4, 3, 2, 1];

  @override
  void initState() {
    super.initState();
    _selectedSort = widget.initialSort;
    _selectedRatingFilter = widget.initialRatingFilter;
  }

  void _clearFilter() {
    setState(() {
      _selectedSort = 'recommended';
      _selectedRatingFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DragHandle(),
          const SizedBox(height: 16),
          _SheetHeader(onClose: () => Navigator.of(context).maybePop()),
          const SizedBox(height: 20),
          _SectionLabel(text: 'Sort by'),
          ..._sortOptions.map(
            (option) => _RadioRow(
              label: option.label,
              isSelected: _selectedSort == option.value,
              onTap: () => setState(() => _selectedSort = option.value),
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel(text: 'Filter by rating'),
          ..._ratingStars.map(
            (star) => _RatingFilterRow(
              star: star,
              count: widget.ratingCounts[star] ?? 0,
              isSelected: _selectedRatingFilter == star,
              onTap: () => setState(() => _selectedRatingFilter = star),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: AdaptiveTextButton(
              onPressed: _clearFilter,
              child: Text(
                'Clear filter',
                style: context.textTheme.bodyLargeMed.copyWith(
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: AdaptiveElevatedButton(
                onPressed: () => Navigator.of(context).pop<ReviewFilterResult>(
                  (sort: _selectedSort, ratingFilter: _selectedRatingFilter),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF344E41),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Text(
                  'Apply',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFD4D4D4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Sort & Filter',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          AdaptiveTap(
            onTap: onClose,
            child: const Icon(Icons.close, color: Colors.black, size: 24),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          style: context.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: Colors.black,
                    ),
                  ),
                ),
                _RadioIndicator(isSelected: isSelected),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
      ],
    );
  }
}

class _RatingFilterRow extends StatelessWidget {
  const _RatingFilterRow({
    required this.star,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final int star;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              children: [
                ...List.generate(5, (index) {
                  final isFilled = index < star;
                  return Icon(
                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 20,
                    color: const Color(0xFF588157),
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  '($count)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                _RadioIndicator(isSelected: isSelected),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
      ],
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF588157),
          width: isSelected ? 6 : 1.5,
        ),
        color: Colors.white,
      ),
      child: isSelected
          ? const Center(
              child: Icon(Icons.circle, color: Colors.white, size: 6),
            )
          : null,
    );
  }
}
