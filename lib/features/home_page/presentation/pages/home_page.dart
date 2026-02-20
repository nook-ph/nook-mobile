import 'package:flutter/material.dart';
import 'package:nook/features/home_page/presentation/widgets/featured_card.dart';
import 'package:nook/features/home_page/presentation/widgets/home_top_bar.dart';
import 'package:nook/features/home_page/presentation/widgets/recommended_card.dart';


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
                padding: EdgeInsetsGeometry.symmetric(horizontal: 22),
                child: Text(
                  "Featured",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 312,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  itemCount: 5,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    return FeaturedCard(
                      width: cardWidth,
                      heroTag: 'featured_cafe_$index',
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
                child: const Column(
                  children: [
                    RecommendedCard(heroTag: 'recommended_1'),
                    SizedBox(height: 14),
                    RecommendedCard(heroTag: 'recommended_2'),
                    SizedBox(height: 14),
                    RecommendedCard(heroTag: 'recommended_3'),
                    SizedBox(height: 14),
                    RecommendedCard(heroTag: 'recommended_4'),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}