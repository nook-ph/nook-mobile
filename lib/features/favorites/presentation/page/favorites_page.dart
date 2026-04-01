import 'package:flutter/material.dart';
import 'package:nook/features/favorites/presentation/widgets/favorite_card.dart';
import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
  
    final List<CafeSummaryEntity> mockFavorites = [
      CafeSummaryEntity(
        id: '1',
        name: 'The Glass Nook',
        rating: 4.8,
        address: 'Setagaya City',
        featuredImageUrl:
            'https://images.unsplash.com/photo-1554118811-1e0d58224f24',
        tags: ['Quiet'],
      ),
      CafeSummaryEntity(
        id: '2',
        name: 'Stone & Steam',
        rating: 4.5,
        address: 'Shinjuku City',
        featuredImageUrl:
            'https://images.unsplash.com/photo-1509042239860-f550ce710b93',
        tags: ['Industrial'],
      ),
      CafeSummaryEntity(
        id: '3',
        name: 'Bloom Bakery',
        rating: 4.9,
        address: 'Shibuya City',
        featuredImageUrl:
            'https://images.unsplash.com/photo-1497935586351-b67a49e012bf',
        tags: ['Pastries'],
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Your Favorites',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 22.0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Section: Count and Filter
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 22.0,
                vertical: 12.0, 
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '12 Cafes saved',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Add your sort/filter logic here
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal:
                            16.0, 
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(24.0),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sort by rating',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 20,
                            color: Colors.black87,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable List of Favorites
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(
                  bottom: 24.0,
                ),
                children: [
                  FavoriteCard(cafe: mockFavorites[0]),
                  FavoriteCard(cafe: mockFavorites[1]),
                  FavoriteCard(cafe: mockFavorites[2]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
