import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nook/features/cafe_details/presentation/pages/cafe_details_page.dart';

class FeaturedCard extends StatelessWidget {
  const FeaturedCard({super.key, required this.width, required this.heroTag});

  final double width;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CafeDetailsPage(heroTag: heroTag),
          ),
        );
      },
      child: Container(
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
              child: Hero(
                tag: heroTag,
                child: Image.network(
                  'https://images.unsplash.com/photo-1497935586351-b67a49e012bf',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Expanded(
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Coffee Madness',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
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
                                  color: Color(0xFF588157),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Icon(
                              LucideIcons.mapPin500,
                              size: 12,
                              color: Color(0xFF848586),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Tayud, Liloan',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF848586),
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
                          padding: const EdgeInsets.symmetric(
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
                              color: Color(0xFF588157),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
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
                              color: Color(0xFF588157),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
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
                              color: Color(0xFF588157),
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
      ),
    );
  }
}
