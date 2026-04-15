import 'package:flutter/material.dart';
import 'package:nook/features/home_page/domain/entities/cafe_summary_entity.dart';
import 'package:nook/features/home_page/presentation/widgets/featured_card.dart';
import 'package:nook/features/home_page/presentation/widgets/home_cafe_section.dart';
import 'package:nook/features/home_page/presentation/widgets/home_top_bar.dart';

final List<CafeSummaryEntity> _featuredCafes = <CafeSummaryEntity>[
  CafeSummaryEntity(
    id: 'featured-1',
    name: 'Nook Greenfield',
    address: 'Makati, Metro Manila',
    rating: 4.8,
    featuredImageUrl:
        'https://images.unsplash.com/photo-1442512595331-e89e73853f31',
    systemBadge: 'Top Pick',
    tags: <String>['Cozy', 'Quiet', 'Wi-Fi'],
  ),
  CafeSummaryEntity(
    id: 'featured-2',
    name: 'Bean District',
    address: 'BGC, Taguig',
    rating: 4.7,
    featuredImageUrl:
        'https://images.unsplash.com/photo-1509042239860-f550ce710b93',
    systemBadge: 'New',
    tags: <String>['Specialty', 'Pastries', 'Work-friendly'],
  ),
];

final List<CafeSummaryEntity> _newCafes = <CafeSummaryEntity>[
  CafeSummaryEntity(
    id: 'new-1',
    name: 'Pour & Pause',
    address: 'Ortigas, Pasig',
    rating: 4.6,
    featuredImageUrl:
        'https://images.unsplash.com/photo-1554118811-1e0d58224f24',
    tags: <String>['Espresso'],
  ),
  CafeSummaryEntity(
    id: 'new-2',
    name: 'Daily Grind Studio',
    address: 'Quezon City',
    rating: 4.5,
    featuredImageUrl:
        'https://images.unsplash.com/photo-1511920170033-f8396924c348',
    tags: <String>['Brunch'],
  ),
  CafeSummaryEntity(
    id: 'new-3',
    name: 'Canvas Coffee',
    address: 'Alabang, Muntinlupa',
    rating: 4.7,
    featuredImageUrl:
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085',
    tags: <String>['Minimalist'],
  ),
];

final List<CafeSummaryEntity> _trendingCafes = <CafeSummaryEntity>[
  CafeSummaryEntity(
    id: 'trending-1',
    name: 'Roast Society',
    address: 'BGC, Taguig',
    rating: 4.9,
    featuredImageUrl:
        'https://images.unsplash.com/photo-1521017432531-fbd92d768814',
    tags: <String>['Crowd Favorite'],
  ),
  CafeSummaryEntity(
    id: 'trending-2',
    name: 'The Slow Drip',
    address: 'Mandaluyong',
    rating: 4.8,
    featuredImageUrl:
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836',
    tags: <String>['Pour-over'],
  ),
  CafeSummaryEntity(
    id: 'trending-3',
    name: 'North Bean House',
    address: 'Quezon City',
    rating: 4.7,
    featuredImageUrl:
        'https://images.unsplash.com/photo-1461988091159-192b6df7054f',
    tags: <String>['Community'],
  ),
];

final List<CafeSummaryEntity> _topRatedCafes = <CafeSummaryEntity>[
  CafeSummaryEntity(
    id: 'top-rated-1',
    name: 'Brew Atelier',
    address: 'Makati, Metro Manila',
    rating: 5.0,
    featuredImageUrl:
        'https://images.unsplash.com/photo-1441986300917-64674bd600d8',
    tags: <String>['Signature'],
  ),
  CafeSummaryEntity(
    id: 'top-rated-2',
    name: 'Linea Coffee Lab',
    address: 'Pasig',
    rating: 4.9,
    featuredImageUrl:
        'https://images.unsplash.com/photo-1517701604599-bb29b565090c',
    tags: <String>['Specialty'],
  ),
  CafeSummaryEntity(
    id: 'top-rated-3',
    name: 'Harbor Espresso',
    address: 'Paranaque',
    rating: 4.9,
    featuredImageUrl:
        'https://images.unsplash.com/photo-1453614512568-c4024d13c247',
    tags: <String>['Premium'],
  ),
];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double cardWidth = screenWidth - 44;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeTopBar(),

              const SizedBox(height: 24),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: const Text(
                  'Featured',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 312,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: _featuredCafes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return FeaturedCard(
                      width: cardWidth,
                      cafe: _featuredCafes[index],
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              HomeCafeSection(
                title: 'New',
                cafes: _newCafes,
              ),

              const SizedBox(height: 24),

              HomeCafeSection(
                title: 'Trending',
                cafes: _trendingCafes,
              ),

              const SizedBox(height: 24),

              HomeCafeSection(
                title: 'Top Rated',
                cafes: _topRatedCafes,
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
