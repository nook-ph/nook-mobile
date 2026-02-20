import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CafeDetailsPage extends StatelessWidget {
  final String heroTag;

  const CafeDetailsPage({super.key, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 70,
        leading: Padding(
          padding: const EdgeInsets.only(left: 22.0),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.black,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
        actions: [
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(
                  LucideIcons.share,
                  color: Colors.black,
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Icon(
                  LucideIcons.heart,
                  color: Colors.black,
                  size: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 22),
        ],
      ),
      extendBodyBehindAppBar: true,

      // ✅ The whole body is scrollable now
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

            // ✅ Removed the Expanded() widget that was causing the white screen!
            // The content continues directly down the column.
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cafe Summit Galleria Cebu',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  '4.9',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Row(
                                  children: [
                                    Icon(Icons.star, size: 16),
                                    SizedBox(width: 2),
                                    Icon(Icons.star, size: 16),
                                    SizedBox(width: 2),
                                    Icon(Icons.star, size: 16),
                                    SizedBox(width: 2),
                                    Icon(Icons.star, size: 16),
                                    SizedBox(width: 2),
                                    Icon(Icons.star, size: 16),
                                  ],
                                ),

                                const SizedBox(width: 4),
                                const Text(
                                  '(32)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  '2.1 km',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF868584),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF868584),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                const Text(
                                  'Tayud, Liloan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF868584),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F893E),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                const Text(
                                  'OPEN NOW',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF344E41),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                const Text(
                                  '|',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF868584),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                const Text(
                                  'Closes at 10 PM',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color(0xFF868584),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tags
                  SizedBox(
                    height: 30,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      itemCount: 4,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return Container(
                          alignment: Alignment.center,
                          height: 30,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF868584)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                LucideIcons.graduationCap,
                                size: 16,
                                color: Color(0xFF868584),
                              ),

                              SizedBox(width: 4),

                              Text(
                                'Student Friendly',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF868584),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

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

                  // Hours Expansion Tile
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        leading: const Icon(
                          LucideIcons.clock,
                          color: Colors.black,
                          size: 20,
                        ),
                        title: const Text(
                          'Hours',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        iconColor: Colors.grey.shade600,
                        collapsedIconColor: Colors.grey.shade600,
                        childrenPadding: const EdgeInsets.only(
                          left: 44,
                          right: 0,
                          bottom: 16,
                        ),
                        children: [
                          _buildDayRow('Sunday', 'Closed', isToday: false),
                          _buildDayRow(
                            'Monday',
                            '8:30 AM - 10:00 PM',
                            isToday: false,
                          ),
                          _buildDayRow(
                            'Tuesday',
                            '8:30 AM - 10:00 PM',
                            isToday: false,
                          ),
                          _buildDayRow(
                            'Wednesday',
                            '8:30 AM - 10:00 PM',
                            isToday: false,
                          ),
                          _buildDayRow(
                            'Thursday',
                            '8:30 AM - 10:00 PM',
                            isToday: true,
                          ),
                          _buildDayRow(
                            'Friday',
                            '8:30 AM - 10:00 PM',
                            isToday: false,
                          ),
                          _buildDayRow(
                            'Saturday',
                            '8:30 AM - 10:00 PM',
                            isToday: false,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Aligned Divider
                  const Padding(
                    padding: EdgeInsets.only(left: 66, right: 22),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE0E0E0),
                    ),
                  ),

                  // Added a little padding at the bottom so it doesn't hug the very edge when fully scrolled down
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(String day, String hours, {required bool isToday}) {
    final color = isToday ? const Color(0xFFD65A5A) : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day, style: TextStyle(fontSize: 12, color: color)),
          Text(hours, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
