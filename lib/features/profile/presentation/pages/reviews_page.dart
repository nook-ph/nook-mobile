import 'package:flutter/material.dart';
import 'package:nook/features/profile/presentation/widgets/review_card.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  int? _selectedStar; // null = all
  String _sortBy = 'Most Recent';

  final List<String> _sortOptions = ['Most Recent', 'Oldest', 'Highest Rated', 'Lowest Rated'];

  final List<Map<String, dynamic>> _allReviews = [
    {'name': 'Name Name Name', 'date': '03/01/25', 'rating': 5.0, 'reviewText': 'Absolutely amazing experience!', 'photos': <String>[]},
    {'name': 'Name Name Name', 'date': '02/28/25', 'rating': 4.9, 'reviewText': 'The quick brown fox jumps over the lazy dog.', 'photos': <String>[]},
    {'name': 'Name Name Name', 'date': '02/20/25', 'rating': 4.0, 'reviewText': 'Pretty good overall, would recommend.', 'photos': <String>[]},
    {'name': 'Name Name Name', 'date': '02/10/25', 'rating': 3.5, 'reviewText': 'It was okay, nothing too special.', 'photos': <String>[]},
    {'name': 'Name Name Name', 'date': '01/30/25', 'rating': 3.0, 'reviewText': 'Average experience, met expectations.', 'photos': <String>[]},
    {'name': 'Name Name Name', 'date': '01/15/25', 'rating': 2.0, 'reviewText': 'A bit disappointing honestly.', 'photos': <String>[]},
    {'name': 'Name Name Name', 'date': '01/05/25', 'rating': 1.0, 'reviewText': 'Would not visit again.', 'photos': <String>[]},
  ];

  List<Map<String, dynamic>> get _filteredReviews {
    List<Map<String, dynamic>> result = [..._allReviews];

    // filter
    if (_selectedStar != null) {
      result = result.where((r) {
        final rating = r['rating'] as double;
        return rating >= _selectedStar! && rating < _selectedStar! + 1;
      }).toList();
    }

    // sort
    if (_sortBy == 'Highest Rated') {
      result.sort((a, b) => (b['rating'] as double).compareTo(a['rating'] as double));
    } else if (_sortBy == 'Lowest Rated') {
      result.sort((a, b) => (a['rating'] as double).compareTo(b['rating'] as double));
    } else if (_sortBy == 'Oldest') {
      result = result.reversed.toList();
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

          // --- Filters ---
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Star filter chips
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

                // Sort dropdown
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

          // --- Reviews List ---
          Expanded(
            child: reviews.isEmpty
                ? const Center(
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
            )
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final review = reviews[index];
                return ReviewCard(
                  name: review['name'] as String,
                  date: review['date'] as String,
                  rating: review['rating'] as double,
                  reviewText: review['reviewText'] as String,
                  photos: review['photos'] as List<String>,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
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
    return GestureDetector(
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