import 'package:flutter/material.dart';
import 'package:nook/features/cafe_details/presentation/widgets/rating_review_summary.dart';
import 'package:nook/features/cafe_details/presentation/widgets/reviews_section.dart';

class ReviewsPage extends StatelessWidget {
  const ReviewsPage({super.key});

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
      body: ListView(
        children: const [
          RatingReviewSummary(),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                ReviewCardPlaceholder(photoCount: 1),
                SizedBox(height: 12),
                ReviewCardPlaceholder(photoCount: 2),
                SizedBox(height: 12),
                ReviewCardPlaceholder(photoCount: 3),
                SizedBox(height: 12),
                ReviewCardPlaceholder(photoCount: 0),
                SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
