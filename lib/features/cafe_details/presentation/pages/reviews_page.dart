import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nook/features/cafe_details/bloc/reviews_bloc.dart';
import 'package:nook/features/cafe_details/bloc/reviews_event.dart';
import 'package:nook/features/cafe_details/bloc/reviews_state.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_bloc.dart';
import 'package:nook/features/cafe_details/bloc/review_submit_state.dart';
import 'package:nook/features/cafe_details/domain/entities/cafe_details_entity.dart';
import 'package:nook/features/cafe_details/presentation/widgets/rating_review_summary.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_section.dart';
import 'package:nook/features/cafe_details/presentation/widgets/write_review_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({
    super.key,
    required this.cafeId,
    this.cafeRating,
    this.reviewCount,
  });

  final String cafeId;
  final double? cafeRating;
  final int? reviewCount;

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  @override
  void initState() {
    super.initState();

    final reviewsState = context.read<ReviewsBloc>().state;
    if (reviewsState is ReviewsLoaded && reviewsState.cafeId == widget.cafeId) {
      return;
    }

    context.read<ReviewsBloc>().add(
      LoadReviewsRequested(cafeId: widget.cafeId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Reviews'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocListener<ReviewSubmitBloc, ReviewSubmitState>(
        listener: (context, state) {
          if (state is ReviewSubmitSuccess) {
            context.read<ReviewsBloc>().add(
              LoadReviewsRequested(cafeId: widget.cafeId),
            );
          }
        },
        child: BlocBuilder<ReviewsBloc, ReviewsState>(
          builder: (context, state) {
            if (state is ReviewsError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF848685),
                    ),
                  ),
                ),
              );
            }

            if (state is! ReviewsLoaded) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF344E41)),
              );
            }

            final reviews = state.reviews;
            final resolvedReviewCount = widget.reviewCount ?? reviews.length;
            final resolvedRating = widget.cafeRating ?? _averageRating(reviews);
            final distribution = _buildDistribution(reviews);

            return ListView(
              children: [
                RatingReviewSummary(
                  rating: resolvedRating,
                  reviewCount: resolvedReviewCount,
                  distribution: distribution,
                  onWriteReviewTap: () {
                    final session =
                        Supabase.instance.client.auth.currentSession;
                    if (session == null) {
                      context.push('/login');
                      return;
                    }

                    WriteReviewSheet.show(context, cafeId: widget.cafeId);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    children: [
                      if (reviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No reviews yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        )
                      else
                        ...reviews.map(
                          (review) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ReviewCard(review: review),
                          ),
                        ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _averageRating(List<ReviewEntity> reviews) {
    if (reviews.isEmpty) return 0;

    final total = reviews.fold<int>(0, (sum, review) => sum + review.rating);
    return total / reviews.length;
  }

  List<RatingDistributionData> _buildDistribution(List<ReviewEntity> reviews) {
    final total = reviews.length;

    return List<RatingDistributionData>.generate(5, (index) {
      final star = 5 - index;
      final count = reviews.where((review) => review.rating == star).length;
      final fill = total == 0 ? 0.0 : count / total;

      return RatingDistributionData(star: star, fill: fill);
    });
  }
}
