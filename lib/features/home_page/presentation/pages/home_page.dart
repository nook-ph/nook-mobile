import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/search/presentation/pages/search_page.dart';

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
              _buildTopBar(context),

              const SizedBox(height: 24),

              Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 22),
                child: Text(
                  "Featured",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 312,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildFeaturedCard(width: cardWidth),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 22),
                child: Text(
                  "Recommended",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 22),
                child: Column(
                  children: [
                    _buildRecommendedCart(),

                    const SizedBox(height: 14),

                    _buildRecommendedCart(),

                    const SizedBox(height: 14),

                    _buildRecommendedCart(),

                    const SizedBox(height: 14),

                    _buildRecommendedCart(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedCart() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
      ),
      height: 112,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Image.network(
              'https://images.unsplash.com/photo-1497935586351-b67a49e012bf',
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          Expanded(
            flex: 8,
            child: Padding(
              padding: EdgeInsetsGeometry.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Coffee Madness',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '5.0',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(width: 6),

                              Icon(
                                Icons.star,
                                color: Color(0xFF588157),

                                size: 16,
                              ),
                            ],
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Icon(
                            LucideIcons.mapPin500,
                            size: 12,
                            color: const Color(0xFF848586),
                          ),

                          const SizedBox(width: 4),

                          Text(
                            'Tayud, Liloan',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF848586),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
                            ),
                            child: const Text(
                              'Student Friendly',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),

                          const SizedBox(width: 6),
                        ],
                      ),

                      Text(
                        '5.0 km',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF848685),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedCard({required double width}) {
    return Container(
      height: 312,
      width: width,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1.0),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 19,
            child: Image.network(
              'https://images.unsplash.com/photo-1497935586351-b67a49e012bf', // Your cafe image URL
              width: double.infinity,
              fit: BoxFit
                  .cover, // ⚠️ CRITICAL: Makes the image fill the area without stretching/squishing
            ),
          ),

          Expanded(
            flex: 11,
            child: Padding(
              padding: EdgeInsetsGeometry.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Coffee Madness',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF588157),
                              ),
                            ),
                            child: const Text(
                              'New',
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF588157),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.mapPin500,
                            size: 12,
                            color: const Color(0xFF848586),
                          ),

                          const SizedBox(width: 4),

                          Text(
                            'Tayud, Liloan',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF848586),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF588157)),
                        ),
                        child: const Text(
                          'New',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF588157),
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF588157)),
                        ),
                        child: const Text(
                          'New',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF588157),
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF588157)),
                        ),
                        child: const Text(
                          'New',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF588157),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, left: 22, right: 22),
      child: Row(
        children: [
          Image.asset(
            'assets/logos/logoT.png',
            height: 28,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 20),

          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const SearchPage(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                  ),
                );
              },
              child: Hero(
                tag: 'search_bar_hero',
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.centerLeft,
                    child: const Row(
                      children: [
                        Icon(LucideIcons.search, color: Colors.grey),
                        SizedBox(width: 8),
                        Text("Search...", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
