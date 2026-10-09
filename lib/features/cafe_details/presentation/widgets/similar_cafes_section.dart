import 'package:flutter/material.dart';
import 'package:nook/core/cafe/domain/entities/cafe_summary.dart';
import 'package:nook/core/cafe/domain/use_cases/get_similar_cafes_usecase.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_common.dart';
import 'package:nook/features/home_page/presentation/widgets/home_card_section.dart';
import 'package:nook/injection_container.dart';

/// "Similar cafes": the cafes nearest to this one by embedding. Renders
/// nothing, divider included, while loading, on error, or with no matches;
/// it is a bonus at the bottom of the page, not something to wait on.
class SimilarCafesSection extends StatefulWidget {
  const SimilarCafesSection({super.key, required this.cafeId});

  final String cafeId;

  @override
  State<SimilarCafesSection> createState() => _SimilarCafesSectionState();
}

class _SimilarCafesSectionState extends State<SimilarCafesSection> {
  late final Future<List<CafeSummary>> _cafes =
      sl<GetSimilarCafesUseCase>()(widget.cafeId).catchError((Object e) {
        debugPrint('SimilarCafesSection: fetch failed $e');
        return <CafeSummary>[];
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CafeSummary>>(
      future: _cafes,
      builder: (context, snapshot) {
        final cafes = snapshot.data ?? const <CafeSummary>[];
        if (cafes.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CafeSectionDivider(),
            HomeCafeSection(title: 'Similar cafes', cafes: cafes),
          ],
        );
      },
    );
  }
}
