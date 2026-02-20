import 'package:flutter/material.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_details_app_bar.dart';

import 'package:nook/features/cafe_details/presentation/widgets/cafe_hours_title.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_info_header.dart';
import 'package:nook/features/cafe_details/presentation/widgets/cafe_tags_list.dart';
import 'package:nook/features/cafe_details/presentation/widgets/menu_highlights.dart';

class CafeDetailsPage extends StatelessWidget {
  const CafeDetailsPage({super.key, required this.heroTag});
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double menuCardWidth = ((screenWidth - 22) / 2) - 6;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const CafeDetailsAppBar(),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image
            Hero(
              tag: heroTag,
              child: Image.network(
                'https://images.unsplash.com/photo-1497935586351-b67a49e012bf',
                height: 350,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 24),

            const CafeInfoHeader(),

            const SizedBox(height: 24),

            const CafeTagsList(),

            const SizedBox(height: 24),

            // Description
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'A refined retreat in the heart of Tayud, Liloan. Cafe Summit Galleria blends contemporary elegance with warm hospitality, featuring plush seating, polished interiors, and ambient lighting. ',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),

            const SizedBox(height: 24),

            const CafeHoursTile(),

            const Padding(
              padding: EdgeInsets.only(left: 66, right: 22),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
            ),

            const SizedBox(height: 24),

            MenuHighlights(width: menuCardWidth),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
