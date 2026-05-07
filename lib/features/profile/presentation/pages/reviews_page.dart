import 'package:flutter/material.dart';
import 'package:nook/core/utils/adaptive_tap.dart';
import 'package:nook/core/cafe/domain/entities/cafe_details.dart';
import 'package:nook/core/cafe/domain/use_cases/get_reviews_written_by_user_usecase.dart';
import 'package:nook/features/profile/presentation/widgets/review_card.dart';
import 'package:nook/injection_container.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  int? _selectedStar;
  String _sortBy = 'Most Recent';

  final List<String> _sortOptions = [
    'Most Recent',
    'Oldest',
    'Highest Rated',
    'Lowest Rated',
  ];

  List<WrittenReview> _allReviews = const [];
  bool _loading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _allReviews = const [];
        _loading = false;
      });
      return;
    }

    try {
      final list = await sl<GetReviewsWrittenByUserUseCase>()(userId);
      if (!mounted) return;
      setState(() {
        _allReviews = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _allReviews = const [];
        _loading = false;
      });
    }
  }

  List<WrittenReview> get _filteredReviews {
    List<WrittenReview> result = [..._allReviews];

    if (_selectedStar != null) {
      result = result.where((r) {
        final rating = r.rating.toDouble();
        return rating >= _selectedStar! && rating < _selectedStar! + 1;
      }).toList();
    }

    if (_sortBy == 'Highest Rated') {
      result.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sortBy == 'Lowest Rated') {
      result.sort((a, b) => a.rating.compareTo(b.rating));
    } else if (_sortBy == 'Oldest') {
      result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _filteredReviews;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Transform.scale(
          scaleX: -1,
          child: IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.black, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          'Reviews',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StarChip(
                        label: 'All',
                        selected: _selectedStar == null,
                        onTap: () => setState(() => _selectedStar = null),
                      ),
                      const SizedBox(width: 8),
                      ...List.generate(5, (i) {
                        final star = 5 - i;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _StarChip(
                            label: '$star ★',
                            selected: _selectedStar == star,
                            onTap: () => setState(() => _selectedStar = star),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Sort by:',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortBy,
                          isDense: true,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            size: 18,
                            color: Colors.black54,
                          ),
                          items: _sortOptions.map((option) {
                            return DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _sortBy = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(reviews),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<WrittenReview> reviews) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                'Could not load reviews.',
                style: TextStyle(color: Colors.grey[800], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadReviews,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (reviews.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No reviews found.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
      itemCount: reviews.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final review = reviews[index];
        return ReviewCard(
          name: review.cafeName,
          date: _formatReviewDate(review.createdAt),
          rating: review.rating.toDouble(),
          reviewText: review.content,
          photos: review.imageUrls,
        );
      },
    );
  }
}

String _formatReviewDate(DateTime date) {
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  final yy = (date.year % 100).toString().padLeft(2, '0');
  return '$mm/$dd/$yy';
}

class _StarChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StarChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF344E41) : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
