import 'package:flutter/material.dart';

class CafeInfoHeader extends StatelessWidget {
  const CafeInfoHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cafe Summit Galleria Cebu',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),

          const SizedBox(height: 6),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rating row
              Row(
                children: [
                  const Text(
                    '4.9',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Distance and location row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '2.1 km',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF868584),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF868584),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Tayud, Liloan',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF868584),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Open status row
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F893E),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'OPEN NOW',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF344E41),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '|',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF868584),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Closes at 10 PM',
                    style: TextStyle(
                      fontSize: 15,
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
    );
  }
}
